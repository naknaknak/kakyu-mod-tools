class_name KakyuMesControlBodyEditCompileReopen
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "body", "relocation", "target_patches", "changed_output_code_offsets",
	"source", "output", "coverage", "invariants", "payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const OPERATION_KEYS := ["kind", "source_start", "source_end", "output_start", "output_end"]
const BODY_KEYS := ["byte_length", "source_raw_sha256", "source_node_count", "inserted_node_count"]
const RELOCATION_KEYS := [
	"delta", "pivot", "address_update_count", "region_update_count", "node_map_count",
	"reference_map_count", "cfg_node_count", "cfg_edge_count", "target_patch_count",
	"target_patch_stream_sha256",
]
const PATCH_KEYS := [
	"reference_id", "reference_kind", "owner_node_id", "owner_op", "command_id",
	"source_instruction_start", "source_instruction_end", "output_instruction_start",
	"output_instruction_end", "source_operand_start", "source_operand_end",
	"output_operand_start", "output_operand_end", "source_target_offset",
	"output_target_offset", "source_target_node_id", "source_raw_hex", "output_raw_hex",
	"encoding",
]
const COVERAGE_KEYS := [
	"expected_output_region_count", "source_node_count", "source_typed_node_count",
	"source_opaque_node_count", "expected_output_node_count",
	"expected_output_typed_node_count", "expected_output_opaque_node_count",
	"source_code_bytes", "output_code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "entry_count_preserved", "code_size_delta_exact",
	"address_table_relocated_exactly", "nonaddress_preamble_bytes_preserved",
	"body_edit_exact", "target_patches_exact", "changed_offsets_exhaustive",
	"source_container_not_modified", "source_documents_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "blocker_free_exact_control_body_plan_new_file_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_control_body_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output: Dictionary = compile_audit.output
	if payload.size() != int(output.size) or ContractValues.sha256(payload) != str(output.entry_sha256):
		return _error("Compiled MES bytes do not match their control-body audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled control-body MES did not reopen: %s" % document.get("error", "failed"))
	var address_end := 4 + int(document.header.entry_count) * 4
	if (
		int(document.header.entry_count) != int(output.entry_count)
		or int(document.header.code_offset) != int(output.code_offset)
		or int(document.header.code_size) != int(output.code_size)
		or str(document.entry_sha256) != str(output.entry_sha256)
		or str(document.bytecode_sha256) != str(output.bytecode_sha256)
		or ContractValues.sha256(payload.slice(0, int(document.header.code_offset))) != str(output.preamble_sha256)
		or ContractValues.sha256(payload.slice(4, address_end)) != str(output.address_table_sha256)
	):
		return _error("GDScript container reopen differs from the control-body audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled control-body MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled control-body MES Phase 1-4 handoff failed: %s" % verified.get("error", "failed"))
	var coverage: Dictionary = compile_audit.coverage
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	if (
		int(coverage.expected_output_region_count) != int(handoff.record_alignment.region_count)
		or int(coverage.expected_output_node_count) != typed_count + opaque_count
		or int(coverage.expected_output_typed_node_count) != typed_count
		or int(coverage.expected_output_opaque_node_count) != opaque_count
		or int(coverage.output_code_bytes) != int(document.header.code_size)
		or int(handoff.record_alignment.framed_bytes) != int(document.header.code_size)
		or int(handoff.record_alignment.failure_count) != 0
	):
		return _error("Compiled control-body MES node partition changed.")
	var patch_verification := _verify_target_patches(document.bytecode, analysis, compile_audit)
	if not patch_verification.ok:
		return patch_verification
	var operation: Dictionary = compile_audit.operation
	var body_boundary := _verify_body_boundary(document.bytecode, analysis.instructions, operation, compile_audit.body)
	if not body_boundary.ok:
		return body_boundary
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_control_body_edit_reopen",
			"contract": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_control_body_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output.duplicate(true),
		"operation": operation.duplicate(true),
		"body_boundary": body_boundary.boundary,
		"target_patch_verification": patch_verification.summary,
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_complete": bool(analysis.complete),
			"analysis_diagnostic_count": int(analysis.diagnostic_count),
			"alignment_failure_count": int(handoff.record_alignment.failure_count),
		},
		"coverage": {
			"region_count": int(handoff.record_alignment.region_count),
			"node_count": typed_count + opaque_count,
			"typed_node_count": typed_count,
			"opaque_node_count": opaque_count,
			"code_bytes": int(document.header.code_size),
		},
		"invariants": {
			"compile_audit_fingerprint_valid": true,
			"output_hashes_match": true,
			"container_reopened": true,
			"analysis_rebuilt": true,
			"handoff_rebuilt_and_verified": true,
			"output_node_partition_exact": true,
			"body_boundary_reindexed": true,
			"target_operands_reindexed": true,
			"code_references_rebuilt": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES control-body compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_control_body_edit_compiler",
		"contract": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_COMPILE_AUDIT_SCHEMA,
	} or document.get("compatibility") != COMPATIBILITY:
		return _error("MES control-body compile producer or compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES control-body compile fingerprint changed.")
	var identity = document.get("source_identity")
	var inputs = document.get("inputs")
	if (
		not identity is Dictionary
		or not ContractValues.has_only_keys(identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(identity.get("entry", "")))
		or not ContractValues.is_sha256(str(identity.get("archive_sha256", "")))
		or not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "control_body_edit_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, inputs.keys())
		or not _valid_summary(document.get("source"))
		or not _valid_summary(document.get("output"))
	):
		return _error("MES control-body compile inputs or summaries changed.")
	var operation = document.get("operation")
	var body = document.get("body")
	var relocation = document.get("relocation")
	var coverage = document.get("coverage")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES control-body compile operation fields changed.")
	if not body is Dictionary or not ContractValues.has_exact_keys(body, BODY_KEYS):
		return _error("MES control-body compile body fields changed.")
	if not relocation is Dictionary or not ContractValues.has_exact_keys(relocation, RELOCATION_KEYS):
		return _error("MES control-body compile relocation fields changed.")
	if not coverage is Dictionary or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS):
		return _error("MES control-body compile coverage fields changed.")
	if str(operation.kind) not in ["insert_typed_body_copy", "remove_typed_body"]:
		return _error("MES control-body compile operation changed.")
	if not _integer_values(operation, ["source_start", "source_end", "output_start", "output_end"]):
		return _error("MES control-body compile operation coordinate changed.")
	if (
		not _integer_values(body, ["byte_length", "source_node_count", "inserted_node_count"])
		or not ContractValues.is_sha256(str(body.source_raw_sha256))
		or int(body.byte_length) != int(operation.source_end) - int(operation.source_start)
		or int(body.source_node_count) <= 0
		or not _json_integer(relocation.delta)
		or not _integer_values(relocation, [
			"pivot", "address_update_count", "region_update_count", "node_map_count",
			"reference_map_count", "cfg_node_count", "cfg_edge_count", "target_patch_count",
		])
		or not ContractValues.is_sha256(str(relocation.target_patch_stream_sha256))
	):
		return _error("MES control-body compile body or relocation changed.")
	var patches = document.get("target_patches")
	var changed = document.get("changed_output_code_offsets")
	if not patches is Array or not changed is Array or patches.size() != int(relocation.target_patch_count):
		return _error("MES control-body compile target patch stream changed.")
	var patch_result := _validate_patches(patches, changed)
	if not patch_result.ok:
		return patch_result
	if _json_sha256(patches) != str(relocation.target_patch_stream_sha256):
		return _error("MES control-body compile target patch fingerprint changed.")
	if (
		not _integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.source_node_count) != int(coverage.source_typed_node_count) + int(coverage.source_opaque_node_count)
		or int(coverage.expected_output_node_count) != int(coverage.expected_output_typed_node_count) + int(coverage.expected_output_opaque_node_count)
		or int(coverage.source_code_bytes) != int(document.source.code_size)
		or int(coverage.output_code_bytes) != int(document.output.code_size)
		or int(document.output.entry_count) != int(document.source.entry_count)
		or int(document.output.code_offset) != int(document.source.code_offset)
		or int(document.output.code_size) != int(document.source.code_size) + int(relocation.delta)
		or int(document.output.size) != int(document.source.size) + int(relocation.delta)
	):
		return _error("MES control-body compile coverage changed.")
	var node_count := int(body.source_node_count)
	if str(operation.kind) == "insert_typed_body_copy" and (
		int(relocation.delta) != int(body.byte_length)
		or int(body.inserted_node_count) != node_count
		or int(operation.output_end) - int(operation.output_start) != int(body.byte_length)
		or int(coverage.expected_output_node_count) != int(coverage.source_node_count) + node_count
	):
		return _error("MES control-body insertion audit changed.")
	if str(operation.kind) == "remove_typed_body" and (
		int(relocation.delta) != -int(body.byte_length)
		or int(body.inserted_node_count) != 0
		or int(operation.output_start) != int(operation.output_end)
		or int(coverage.expected_output_node_count) != int(coverage.source_node_count) - node_count
	):
		return _error("MES control-body removal audit changed.")
	var invariants = document.get("invariants")
	if not invariants is Dictionary or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS) or not ContractValues.all_true(invariants):
		return _error("MES control-body compile invariants changed.")
	return {"ok": true, "schema": ContentCoreVersionScript.MES_CONTROL_BODY_EDIT_COMPILE_AUDIT_SCHEMA, "payload_sha256": retained_hash}


func _verify_body_boundary(
	code: PackedByteArray, instructions: Array, operation: Dictionary, body: Dictionary
) -> Dictionary:
	var output_start := int(operation.output_start)
	var output_end := int(operation.output_end)
	if str(operation.kind) == "insert_typed_body_copy":
		if ContractValues.sha256(code.slice(output_start, output_end)) != str(body.source_raw_sha256):
			return _error("Compiled MES inserted body bytes changed.")
		var inserted := 0
		for value in instructions:
			var instruction: Dictionary = value
			if int(instruction.source_offset) >= output_start and int(instruction.end_offset) <= output_end:
				inserted += 1
		if inserted != int(body.inserted_node_count):
			return _error("Compiled MES inserted body partition changed.")
		return {"ok": true, "boundary": {"kind": str(operation.kind), "output_start": output_start, "output_end": output_end, "node_count": inserted, "raw_sha256": str(body.source_raw_sha256)}}
	var resumes := 0
	for value in instructions:
		if int((value as Dictionary).source_offset) == output_start:
			resumes += 1
	if resumes != 1:
		return _error("Compiled MES removal resume boundary was not uniquely reindexed.")
	return {"ok": true, "boundary": {"kind": str(operation.kind), "output_start": output_start, "output_end": output_end, "node_count": 0, "raw_sha256": str(body.source_raw_sha256)}}


func _verify_target_patches(code: PackedByteArray, analysis: Dictionary, audit: Dictionary) -> Dictionary:
	var reference_count := 0
	var definition_count := 0
	for value in audit.target_patches:
		var patch: Dictionary = value
		if code.slice(int(patch.output_operand_start), int(patch.output_operand_end)).hex_encode() != str(patch.output_raw_hex):
			return _error("Compiled MES target operand bytes changed after reopen.")
		var instruction_matches := 0
		for instruction_value in analysis.instructions:
			if int((instruction_value as Dictionary).source_offset) == int(patch.output_instruction_start):
				instruction_matches += 1
		if instruction_matches != 1:
			return _error("Compiled MES target owner was not uniquely reindexed.")
		if str(patch.reference_kind) == "definition_skip_target":
			definition_count += 1
			continue
		var matches := 0
		for reference_value in analysis.code_references:
			var reference: Dictionary = reference_value
			if (
				int(reference.source_offset) == int(patch.output_instruction_start)
				and str(reference.kind) == str(patch.reference_kind)
				and int(reference.target_offset) == int(patch.output_target_offset)
				and reference.get("aligned") == true
				and reference.get("in_code") == true
			):
				matches += 1
		if matches != 1:
			return _error("Compiled MES code reference did not rebuild exactly.")
		reference_count += 1
	return {"ok": true, "summary": {"patch_count": audit.target_patches.size(), "code_reference_count": reference_count, "definition_skip_count": definition_count, "patch_stream_sha256": str(audit.relocation.target_patch_stream_sha256)}}


func _validate_patches(patches: Array, changed: Array) -> Dictionary:
	var expected_changed: Array[int] = []
	var previous_end := -1
	for value in patches:
		if not value is Dictionary or not ContractValues.has_exact_keys(value, PATCH_KEYS):
			return _error("MES control-body compile target patch fields changed.")
		var patch: Dictionary = value
		var source_raw := str(patch.source_raw_hex).hex_decode()
		var output_raw := str(patch.output_raw_hex).hex_decode()
		if (
			str(patch.encoding) != "u32_le_absolute_code_offset"
			or source_raw.size() != 4 or output_raw.size() != 4
			or int(patch.output_operand_start) < previous_end
			or int(patch.source_operand_end) - int(patch.source_operand_start) != 4
			or int(patch.output_operand_end) - int(patch.output_operand_start) != 4
			or source_raw.decode_u32(0) != int(patch.source_target_offset)
			or output_raw.decode_u32(0) != int(patch.output_target_offset)
		):
			return _error("MES control-body compile target patch changed.")
		for index in range(4):
			if source_raw[index] != output_raw[index]:
				expected_changed.append(int(patch.output_operand_start) + index)
		previous_end = int(patch.output_operand_end)
	var normalized: Array[int] = []
	for value in changed:
		if not _nonnegative_json_integer(value):
			return _error("MES control-body compile changed offset changed.")
		normalized.append(int(value))
	if normalized != expected_changed:
		return _error("MES control-body compile changed offsets changed.")
	return {"ok": true}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _json_sha256(value: Variant) -> String:
	return ContractValues.sha256(JSON.stringify(_normalize_json_numbers(value), "", true, true).to_utf8_buffer())


func _normalize_json_numbers(value: Variant) -> Variant:
	if value is float and float(value) == floor(float(value)):
		return int(value)
	if value is Array:
		var output: Array = []
		for child in value:
			output.append(_normalize_json_numbers(child))
		return output
	if value is Dictionary:
		var output := {}
		for key in value:
			output[key] = _normalize_json_numbers(value[key])
		return output
	return value


func _valid_summary(value: Variant) -> bool:
	return value is Dictionary and ContractValues.has_exact_keys(value, SUMMARY_KEYS) and _integer_values(value, ["size", "entry_count", "code_offset", "code_size"]) and ContractValues.hash_values(value, ["entry_sha256", "bytecode_sha256", "preamble_sha256", "address_table_sha256"]) and int(value.size) == int(value.code_offset) + int(value.code_size)


func _integer_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not _nonnegative_json_integer(document.get(key, -1)):
			return false
	return true


func _json_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and abs(float(value)) <= 4294967295.0


func _nonnegative_json_integer(value: Variant) -> bool:
	return _json_integer(value) and int(value) >= 0


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
