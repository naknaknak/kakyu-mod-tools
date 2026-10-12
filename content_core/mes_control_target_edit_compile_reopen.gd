class_name KakyuMesControlTargetEditCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"source", "output", "operation", "source_control", "replacement_target",
	"patch", "coverage", "invariants", "payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const OPERATION_KEYS := [
	"kind", "reference_kind", "source_offset", "current_target_offset",
	"replacement_target_offset",
]
const SOURCE_CONTROL_KEYS := [
	"node_id", "source_region_id", "instruction_start", "instruction_end",
	"source_instruction_sha256", "replacement_instruction_sha256", "op",
	"command_id", "reference_id", "reference_kind", "operand_start",
	"operand_end", "expression_kind", "expression_start", "expression_end",
	"expression_sha256", "current_target_node_id",
]
const REPLACEMENT_TARGET_KEYS := [
	"node_id", "source_region_id", "instruction_start", "instruction_end",
	"instruction_sha256", "op", "command_id",
]
const PATCH_KEYS := [
	"operand_start", "operand_end", "source_raw_hex", "output_raw_hex",
	"changed_code_offsets", "encoding",
]
const COVERAGE_KEYS := [
	"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "container_size_preserved",
	"entry_count_preserved", "code_offset_preserved", "code_size_preserved",
	"address_table_preserved", "preamble_preserved", "code_prefix_preserved",
	"replacement_instruction_exact", "code_suffix_preserved",
	"changed_offsets_exact", "source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "exact_same_width_control_target_edit_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_control_target_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"relocation": "forbidden",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output: Dictionary = compile_audit.output
	if payload.size() != int(output.size) or ContractValues.sha256(payload) != str(output.entry_sha256):
		return _error("Compiled MES bytes do not match their control-target edit audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled control-target MES did not reopen.")
	if (
		int(document.header.entry_count) != int(output.entry_count)
		or int(document.header.code_offset) != int(output.code_offset)
		or int(document.header.code_size) != int(output.code_size)
		or str(document.entry_sha256) != str(output.entry_sha256)
		or str(document.bytecode_sha256) != str(output.bytecode_sha256)
		or ContractValues.sha256(payload.slice(0, int(document.header.code_offset))) != str(output.preamble_sha256)
	):
		return _error("GDScript container reopen differs from the control-target edit audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled control-target MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled control-target MES Phase 1-4 handoff failed.")
	var coverage: Dictionary = compile_audit.coverage
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	if (
		not CompileCoverageScript.regions_match(coverage, document, handoff.record_alignment)
		or int(coverage.node_count) != typed_count + opaque_count
		or int(coverage.typed_node_count) != typed_count
		or int(coverage.opaque_node_count) != opaque_count
		or int(coverage.code_bytes) != int(document.header.code_size)
	):
		return _error("Compiled control-target MES node partition changed.")
	var edge := _verify_edited_edge(document.bytecode, analysis, compile_audit)
	if not edge.ok:
		return edge
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_control_target_edit_reopen",
			"contract": ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_REOPEN_AUDIT_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output.duplicate(true),
		"edited_edge": edge.edge,
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_complete": bool(analysis.complete),
			"analysis_diagnostic_count": int(analysis.diagnostic_count),
			"alignment_failure_count": int(handoff.record_alignment.failure_count),
		},
		"coverage": {
			"region_count": CompileCoverageScript.region_count(document),
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
			"source_node_partition_preserved": true,
			"edited_instruction_reindexed": true,
			"replacement_target_reindexed": true,
			"code_reference_rebuilt": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES control-target edit compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_control_target_edit_compiler",
		"contract": ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_COMPILE_AUDIT_SCHEMA,
	} or document.get("compatibility") != COMPATIBILITY:
		return _error("MES control-target edit compile producer or compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES control-target edit compile fingerprint changed.")
	var inputs = document.get("inputs")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
		or not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "control_target_edit_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, inputs.keys())
		or not _valid_summary(document.get("source"))
		or not _valid_summary(document.get("output"))
	):
		return _error("MES control-target edit compile inputs or summaries changed.")
	var source: Dictionary = document.source
	var output: Dictionary = document.output
	for key in ["size", "entry_count", "code_offset", "code_size", "preamble_sha256", "address_table_sha256"]:
		if output.get(key) != source.get(key):
			return _error("MES control-target edit compile layout preservation changed.")
	var operation = document.get("operation")
	var control = document.get("source_control")
	var target = document.get("replacement_target")
	var patch = document.get("patch")
	var coverage = document.get("coverage")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES control-target edit compile operation fields changed.")
	if not control is Dictionary or not ContractValues.has_exact_keys(control, SOURCE_CONTROL_KEYS):
		return _error("MES control-target edit compile source fields changed.")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, REPLACEMENT_TARGET_KEYS):
		return _error("MES control-target edit compile replacement fields changed.")
	if not patch is Dictionary or not ContractValues.has_exact_keys(patch, PATCH_KEYS):
		return _error("MES control-target edit compile patch fields changed.")
	if not coverage is Dictionary or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS):
		return _error("MES control-target edit compile coverage fields changed.")
	for value in [operation.source_offset, operation.current_target_offset, operation.replacement_target_offset, control.instruction_start, control.instruction_end, control.command_id, control.operand_start, control.operand_end, control.expression_start, control.expression_end, target.instruction_start, target.instruction_end, target.command_id, patch.operand_start, patch.operand_end]:
		if not _nonnegative_json_integer(value):
			return _error("MES control-target edit compile coordinate changed.")
	if (
		str(operation.kind) != "retarget_control_flow"
		or str(operation.reference_kind) not in ["condition_false_target", "continuation_target"]
		or int(operation.current_target_offset) == int(operation.replacement_target_offset)
		or int(operation.source_offset) != int(control.instruction_start)
		or int(operation.replacement_target_offset) != int(target.instruction_start)
		or str(control.reference_kind) != str(operation.reference_kind)
		or int(control.operand_start) != int(patch.operand_start)
		or int(control.operand_end) != int(patch.operand_end)
		or int(patch.operand_end) - int(patch.operand_start) != 4
		or str(patch.encoding) != "u32_le_absolute_code_offset"
		or _decode_u32(str(patch.source_raw_hex)) != int(operation.current_target_offset)
		or _decode_u32(str(patch.output_raw_hex)) != int(operation.replacement_target_offset)
	):
		return _error("MES control-target edit compile coordinate binding changed.")
	for value in [control.node_id, control.source_region_id, control.op, control.reference_id, control.current_target_node_id, target.node_id, target.source_region_id, target.op]:
		if str(value).is_empty():
			return _error("MES control-target edit compile identity changed.")
	for value in [control.source_instruction_sha256, control.replacement_instruction_sha256, control.expression_sha256, target.instruction_sha256]:
		if not ContractValues.is_sha256(str(value)):
			return _error("MES control-target edit compile hash changed.")
	var changed = patch.get("changed_code_offsets")
	if not changed is Array or changed.is_empty():
		return _error("MES control-target edit compile changed-offset list changed.")
	var normalized_changed: Array[int] = []
	for value in changed:
		if not _nonnegative_json_integer(value):
			return _error("MES control-target edit compile changed-offset list changed.")
		normalized_changed.append(int(value))
	var expected_changed: Array[int] = []
	var source_operand := str(patch.source_raw_hex).hex_decode()
	var output_operand := str(patch.output_raw_hex).hex_decode()
	for index in range(4):
		if source_operand[index] != output_operand[index]:
			expected_changed.append(int(patch.operand_start) + index)
	if normalized_changed != expected_changed:
		return _error("MES control-target edit compile changed offsets changed.")
	if (
		int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES control-target edit compile coverage changed.")
	for key in COVERAGE_KEYS:
		if not _nonnegative_json_integer(coverage.get(key, -1)):
			return _error("MES control-target edit compile coverage count changed.")
	var invariants = document.get("invariants")
	if not invariants is Dictionary or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS):
		return _error("MES control-target edit compile invariants changed.")
	for value in invariants.values():
		if value != true:
			return _error("MES control-target edit compile invariants changed.")
	return {"ok": true, "schema": ContentCoreVersionScript.MES_CONTROL_TARGET_EDIT_COMPILE_AUDIT_SCHEMA, "payload_sha256": retained_hash}


func _verify_edited_edge(code: PackedByteArray, analysis: Dictionary, audit: Dictionary) -> Dictionary:
	var operation: Dictionary = audit.operation
	var control: Dictionary = audit.source_control
	var target: Dictionary = audit.replacement_target
	var patch: Dictionary = audit.patch
	var instruction_matches: Array[Dictionary] = []
	var target_matches: Array[Dictionary] = []
	for untyped in analysis.instructions:
		var instruction: Dictionary = untyped
		if int(instruction.source_offset) == int(control.instruction_start):
			instruction_matches.append(instruction)
		if int(instruction.source_offset) == int(target.instruction_start):
			target_matches.append(instruction)
	if instruction_matches.size() != 1 or target_matches.size() != 1:
		return _error("Compiled MES edited edge endpoints were not uniquely reindexed.")
	var instruction := instruction_matches[0]
	var target_instruction := target_matches[0]
	if (
		str(instruction.op) != str(control.op)
		or int(instruction.command_id) != int(control.command_id)
		or int(instruction.end_offset) != int(control.instruction_end)
		or ContractValues.sha256(code.slice(int(control.instruction_start), int(control.instruction_end))) != str(control.replacement_instruction_sha256)
		or int(target_instruction.end_offset) != int(target.instruction_end)
		or str(target_instruction.op) != str(target.op)
		or int(target_instruction.command_id) != int(target.command_id)
		or ContractValues.sha256(code.slice(int(target.instruction_start), int(target.instruction_end))) != str(target.instruction_sha256)
	):
		return _error("Compiled MES edited edge endpoint bytes changed.")
	if code.slice(int(patch.operand_start), int(patch.operand_end)).hex_encode() != str(patch.output_raw_hex):
		return _error("Compiled MES edited target operand bytes changed.")
	if str(control.expression_kind) == "condition" and ContractValues.sha256(code.slice(int(control.expression_start), int(control.expression_end))) != str(control.expression_sha256):
		return _error("Compiled MES edited branch condition changed.")
	var references: Array[Dictionary] = []
	for untyped in analysis.code_references:
		var reference: Dictionary = untyped
		if int(reference.source_offset) == int(control.instruction_start) and str(reference.kind) == str(operation.reference_kind):
			references.append(reference)
	if (
		references.size() != 1
		or int(references[0].target_offset) != int(target.instruction_start)
		or references[0].get("aligned") != true
		or references[0].get("in_code") != true
	):
		return _error("Compiled MES edited code reference did not rebuild exactly.")
	return {
		"ok": true,
		"edge": {
			"reference_kind": str(operation.reference_kind),
			"source_offset": int(control.instruction_start),
			"instruction_end": int(control.instruction_end),
			"current_target_offset": int(operation.current_target_offset),
			"replacement_target_offset": int(target.instruction_start),
			"replacement_target_end": int(target.instruction_end),
			"replacement_target_op": str(target.op),
			"changed_code_offsets": patch.changed_code_offsets.duplicate(),
		},
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _valid_summary(value: Variant) -> bool:
	if not value is Dictionary or not ContractValues.has_exact_keys(value, SUMMARY_KEYS):
		return false
	for key in ["size", "entry_count", "code_offset", "code_size"]:
		if not _nonnegative_json_integer(value.get(key, -1)):
			return false
	return ContractValues.hash_values(value, ["entry_sha256", "bytecode_sha256", "preamble_sha256", "address_table_sha256"]) and int(value.size) == int(value.code_offset) + int(value.code_size)


func _decode_u32(value: String) -> int:
	var bytes := value.hex_decode()
	return int(bytes.decode_u32(0)) if bytes.size() == 4 else -1


func _nonnegative_json_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0.0 and float(value) <= 4294967295.0


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
