class_name KakyuMesStateLiteralCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"source", "output", "operation", "target", "coverage", "invariants",
	"payload_sha256",
]
const SUMMARY_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "pair_index", "storage", "source_value",
	"replacement_value", "width",
]
const TARGET_KEYS := [
	"node_id", "region_id", "instruction_start", "instruction_end",
	"expression_start", "expression_end", "source_instruction_sha256",
	"replacement_instruction_sha256", "source_expression_sha256",
	"replacement_expression_sha256",
]
const COVERAGE_KEYS := [
	"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "container_size_preserved",
	"entry_count_preserved", "code_offset_preserved", "code_size_preserved",
	"address_table_preserved", "preamble_preserved", "code_prefix_preserved",
	"replacement_instruction_exact", "code_suffix_preserved",
	"source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const STORAGE_FORMS := {
	"global_u8": {"op": "global_u8_write_run", "pairs_operand": 1.0},
	"state_u16": {"op": "state_u16_write_run", "pairs_operand": 1.0},
	"banked_u8": {"op": "banked_u8_write_run", "pairs_operand": 2.0},
	"banked_u16": {"op": "banked_u16_write_run", "pairs_operand": 2.0},
	"banked_i32": {"op": "banked_i32_write_run", "pairs_operand": 2.0},
	"global_i32": {"op": "global_i32_write_run", "pairs_operand": 1.0},
}
const COMPATIBILITY := {
	"policy": "exact_same_width_state_literal_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_state_literal_edit_plan/v1",
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
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their state literal compile audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled state literal MES did not reopen: %s" % document.get("error", "failed"))
	var code_offset := int(document.header.code_offset)
	var preamble := payload.slice(0, code_offset)
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or code_offset != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256(preamble) != str(output_row.preamble_sha256)
		or ContractValues.sha256(preamble) != str(output_row.address_table_sha256)
	):
		return _error("GDScript MES container reopen differs from the state literal compile audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled state literal MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled state literal MES Phase 1-4 handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled state literal MES source identity changed during reopen.")
	var coverage: Dictionary = compile_audit.coverage
	var alignment: Dictionary = handoff.record_alignment
	var typed_count := int((handoff.typed_ir.instructions as Array).size())
	var opaque_count := int((handoff.typed_ir.opaque_boundaries as Array).size())
	if (
		not CompileCoverageScript.regions_match(coverage, document, alignment)
		or int(coverage.typed_node_count) != typed_count
		or int(coverage.opaque_node_count) != opaque_count
		or int(coverage.node_count) != typed_count + opaque_count
		or int(coverage.code_bytes) != int(document.header.code_size)
		or int(alignment.framed_bytes) != int(document.header.code_size)
	):
		return _error("GDScript Phase 1-4 coverage differs from the state literal compile audit.")
	var edited_write := _find_edited_write(analysis.instructions, compile_audit.operation, compile_audit.target)
	if not edited_write.ok:
		return edited_write
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_STATE_LITERAL_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_state_literal_reopen",
			"contract": ContentCoreVersionScript.MES_STATE_LITERAL_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_state_literal_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_STATE_LITERAL_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_write": edited_write.write,
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_complete": bool(analysis.complete),
			"analysis_diagnostic_count": int(analysis.diagnostic_count),
			"alignment_failure_count": int(alignment.failure_count),
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
			"alignment_rebuilt": true,
			"handoff_rebuilt_and_verified": true,
			"source_node_partition_preserved": true,
			"replacement_write_reindexed": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_STATE_LITERAL_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES state literal compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_state_literal_compiler",
		"contract": ContentCoreVersionScript.MES_STATE_LITERAL_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES state literal compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES state literal compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES state literal compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or str(source_identity.get("entry", "")).is_empty()
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
	):
		return _error("MES state literal compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "state_literal_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "state_literal_plan_sha256",
		])
	):
		return _error("MES state literal compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES state literal compile container summary changed.")
	if (
		int(output.size) != int(source.size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size)
		or str(output.preamble_sha256) != str(source.preamble_sha256)
		or str(output.address_table_sha256) != str(source.address_table_sha256)
	):
		return _error("MES state literal compile layout preservation changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_state_write_literal"
		or not STORAGE_FORMS.has(str(operation.get("storage", "")))
		or not ContractValues.nonnegative_integer_values(operation, [
			"source_offset", "pair_index", "source_value", "replacement_value", "width",
		])
		or int(operation.width) not in [8, 16, 32]
	):
		return _error("MES state literal compile operation changed.")
	var target = document.get("target")
	if (
		not target is Dictionary
		or not ContractValues.has_exact_keys(target, TARGET_KEYS)
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or not ContractValues.nonnegative_integer_values(target, [
			"instruction_start", "instruction_end", "expression_start", "expression_end",
		])
		or not ContractValues.hash_values(target, [
			"source_instruction_sha256", "replacement_instruction_sha256",
			"source_expression_sha256", "replacement_expression_sha256",
		])
		or int(target.instruction_end) <= int(target.instruction_start)
		or int(target.expression_start) < int(target.instruction_start)
		or int(target.expression_end) >= int(target.instruction_end)
		or int(operation.source_offset) != int(target.instruction_start)
	):
		return _error("MES state literal compile target changed.")
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS)
		or not ContractValues.nonnegative_integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES state literal compile coverage changed.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES state literal compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_STATE_LITERAL_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_write(instructions: Array, operation: Dictionary, target: Dictionary) -> Dictionary:
	var matches: Array[Dictionary] = []
	for untyped_instruction in instructions:
		var instruction: Dictionary = untyped_instruction
		if int(instruction.source_offset) == int(target.instruction_start):
			matches.append(instruction)
	if matches.size() != 1:
		return _error("Compiled MES edited state write was not uniquely reindexed.")
	var instruction: Dictionary = matches[0]
	var storage_form: Dictionary = STORAGE_FORMS.get(str(operation.storage), {})
	if (
		str(instruction.op) != str(storage_form.get("op", ""))
		or int(instruction.end_offset) != int(target.instruction_end)
		or ContractValues.sha256(str(instruction.raw_hex).hex_decode()) != str(target.replacement_instruction_sha256)
	):
		return _error("Compiled MES edited state instruction differs from its audit.")
	var operands: Array = instruction.get("operands", [])
	var pairs_index := int(storage_form.get("pairs_operand", -1))
	if pairs_index < 0 or pairs_index >= operands.size():
		return _error("Compiled MES edited state pair owner changed.")
	var pair_owner: Dictionary = operands[pairs_index]
	var pairs: Array = pair_owner.get("pairs", [])
	var pair_index := int(operation.pair_index)
	if pair_index < 0 or pair_index >= pairs.size():
		return _error("Compiled MES edited state pair index changed.")
	var pair: Dictionary = pairs[pair_index]
	var expression: Dictionary = pair.get("expression", {})
	var ast: Dictionary = expression.get("ast", {})
	if (
		int(expression.get("offset", -1)) != int(target.expression_start)
		or int(expression.get("end_offset", -1)) != int(target.expression_end)
		or ContractValues.sha256(str(expression.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_expression_sha256)
		or str(ast.get("type", "")) != "literal"
		or int(ast.get("value", -1)) != int(operation.replacement_value)
		or int(ast.get("width", -1)) != int(operation.width)
	):
		return _error("Compiled MES edited state expression differs from its audit.")
	return {
		"ok": true,
		"write": {
			"op": str(instruction.op),
			"storage": str(operation.storage),
			"instruction_start": int(instruction.source_offset),
			"instruction_end": int(instruction.end_offset),
			"instruction_sha256": str(target.replacement_instruction_sha256),
			"pair_index": pair_index,
			"expression_start": int(expression.offset),
			"expression_end": int(expression.end_offset),
			"expression_sha256": str(target.replacement_expression_sha256),
			"value": int(ast.value),
			"width": int(ast.width),
		},
	}


func _valid_summary(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	return (
		ContractValues.has_exact_keys(row, SUMMARY_KEYS)
		and ContractValues.nonnegative_integer_values(row, ["size", "entry_count", "code_offset", "code_size"])
		and ContractValues.hash_values(row, [
			"entry_sha256", "bytecode_sha256", "preamble_sha256", "address_table_sha256",
		])
		and int(row.size) == int(row.code_offset) + int(row.code_size)
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
