class_name KakyuMesInlineScriptNameCompileReopen
extends RefCounted

const CompileCoverageScript := preload("res://content_core/mes_compile_coverage.gd")

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
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
	"kind", "source_offset", "reference_id", "source_name", "replacement_name",
	"execution_selector", "execution_role",
]
const TARGET_KEYS := [
	"node_id", "region_id", "owner_kind", "owner_start", "owner_end",
	"owner_bytes", "envelope_start", "envelope_end", "name_start", "name_end",
	"name_bytes", "prefix_bytes", "suffix_bytes", "source_owner_sha256",
	"replacement_owner_sha256", "source_envelope_sha256",
	"replacement_envelope_sha256", "source_name_sha256",
	"replacement_name_sha256", "prefix_sha256", "suffix_sha256",
	"reference_boundary",
]
const COVERAGE_KEYS := [
	"region_count", "node_count", "typed_node_count", "opaque_node_count", "code_bytes",
]
const INVARIANT_KEYS := [
	"plan_ready", "output_reopened", "container_size_preserved",
	"entry_count_preserved", "code_offset_preserved", "code_size_preserved",
	"address_table_preserved", "preamble_preserved", "code_prefix_preserved",
	"code_suffix_preserved", "replacement_envelope_exact",
	"owner_prefix_preserved", "owner_suffix_preserved", "selector_prefix_preserved",
	"double_nul_suffix_preserved", "only_name_range_changed",
	"opaque_owner_boundary_preserved", "source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const SUPPORTED_SELECTORS := {
	2: {"extension": "lib", "role": "library_bootstrap"},
	3: {"extension": "mes", "role": "definition_bootstrap"},
}
const COMPATIBILITY := {
	"policy": "exact_same_length_inline_script_name_plan_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_plan_schema": "kakyu_mes_inline_script_name_edit_plan/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
	"output_policy": "new_file_only",
	"relocation": "forbidden",
	"resource_existence": "not_checked",
	"tool_execution": "not_performed",
	"native_engine_compatibility": "unverified",
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var validation := validate_compile_audit(compile_audit)
	if not validation.ok:
		return validation
	var output_row: Dictionary = compile_audit.output
	if payload.size() != int(output_row.size) or ContractValues.sha256_lenient(payload) != str(output_row.entry_sha256):
		return _error("Compiled MES bytes do not match their inline script name audit.")
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled inline script name MES did not reopen: %s" % document.get("error", "failed"))
	var code_offset := int(document.header.code_offset)
	var preamble := payload.slice(0, code_offset)
	var address_table := payload.slice(4, code_offset)
	if (
		int(document.header.entry_count) != int(output_row.entry_count)
		or code_offset != int(output_row.code_offset)
		or int(document.header.code_size) != int(output_row.code_size)
		or str(document.entry_sha256) != str(output_row.entry_sha256)
		or str(document.bytecode_sha256) != str(output_row.bytecode_sha256)
		or ContractValues.sha256_lenient(preamble) != str(output_row.preamble_sha256)
		or ContractValues.sha256_lenient(address_table) != str(output_row.address_table_sha256)
	):
		return _error("GDScript container reopen differs from the inline script name audit.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled inline script name MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.get("ok", false):
		return _error("Compiled inline script name MES handoff failed: %s" % verified.get(
			"error", handoff.get("error", "failed")
		))
	if handoff.source_identity != source_identity:
		return _error("Compiled inline script name MES source identity changed during reopen.")
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
		return _error("Phase 1-4 coverage differs from the inline script name audit.")
	var edited_call := _find_edited_call(
		document.bytecode, analysis, compile_audit.operation, compile_audit.target
	)
	if not edited_call.ok:
		return edited_call
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_inline_script_name_reopen",
			"contract": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_REOPEN_AUDIT_SCHEMA,
		},
		"compatibility": {
			"policy": "exact_inline_script_name_compile_audit_and_current_phase1_4_schemas",
			"input_compile_audit_schema": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_COMPILE_AUDIT_SCHEMA,
			"container_schema": ContentCoreVersionScript.MES_CONTAINER_SCHEMA,
			"analysis_schema": ContentCoreVersionScript.MES_ANALYSIS_SCHEMA,
			"record_alignment_schema": ContentCoreVersionScript.MES_RECORD_ALIGNMENT_AUDIT_SCHEMA,
			"analyzer_handoff_schema": ContentCoreVersionScript.MES_ANALYZER_HANDOFF_SCHEMA,
		},
		"source_identity": source_identity,
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output_row.duplicate(true),
		"edited_call": edited_call.call,
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
			"replacement_envelope_redecoded": true,
			"replacement_name_redecoded": true,
			"resource_reference_reindexed": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES inline script name compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_inline_script_name_compiler",
		"contract": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES inline script name compile audit producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES inline script name compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES inline script name compile audit fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
	):
		return _error("MES inline script name compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "inline_script_name_plan_sha256",
		])
		or not ContractValues.hash_values(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256", "inline_script_name_plan_sha256",
		])
	):
		return _error("MES inline script name compile input identity changed.")
	var source = document.get("source")
	var output = document.get("output")
	if not _valid_summary(source) or not _valid_summary(output):
		return _error("MES inline script name compile container summary changed.")
	if (
		int(output.size) != int(source.size)
		or int(output.entry_count) != int(source.entry_count)
		or int(output.code_offset) != int(source.code_offset)
		or int(output.code_size) != int(source.code_size)
		or str(output.preamble_sha256) != str(source.preamble_sha256)
		or str(output.address_table_sha256) != str(source.address_table_sha256)
	):
		return _error("MES inline script name compile layout preservation changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_inline_script_name"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or str(operation.get("reference_id", "")).is_empty()
		or not ArcReaderScript.is_safe_entry_name(str(operation.get("source_name", "")))
		or not ArcReaderScript.is_safe_entry_name(str(operation.get("replacement_name", "")))
		or not ContractValues.nonnegative_json_integer(operation.get("execution_selector", -1))
		or not SUPPORTED_SELECTORS.has(int(operation.execution_selector))
		or str(operation.get("execution_role", ""))
		!= str(SUPPORTED_SELECTORS[int(operation.execution_selector)].role)
	):
		return _error("MES inline script name compile operation changed.")
	var target = document.get("target")
	var owner_kind := str(target.get("owner_kind", "")) if target is Dictionary else ""
	if (
		not target is Dictionary
		or not ContractValues.has_exact_keys(target, TARGET_KEYS)
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or owner_kind not in ["statement", "opaque"]
		or str(target.get("reference_boundary", ""))
		!= ("strict_indexed" if owner_kind == "statement" else "bounded_envelope_scan")
		or not ContractValues.nonnegative_integer_values(target, [
			"owner_start", "owner_end", "owner_bytes", "envelope_start", "envelope_end",
			"name_start", "name_end", "name_bytes", "prefix_bytes", "suffix_bytes",
		])
		or not ContractValues.hash_values(target, [
			"source_owner_sha256", "replacement_owner_sha256",
			"source_envelope_sha256", "replacement_envelope_sha256",
			"source_name_sha256", "replacement_name_sha256", "prefix_sha256",
			"suffix_sha256",
		])
		or int(target.owner_end) != int(target.owner_start) + int(target.owner_bytes)
		or int(target.envelope_start) < int(target.owner_start)
		or int(target.envelope_end) > int(target.owner_end)
		or int(target.name_start) != int(target.envelope_start) + int(target.prefix_bytes)
		or int(target.name_end) != int(target.name_start) + int(target.name_bytes)
		or int(target.envelope_end) != int(target.name_end) + int(target.suffix_bytes)
		or int(operation.source_offset) != int(target.envelope_start)
	):
		return _error("MES inline script name compile target changed.")
	var coverage = document.get("coverage")
	if (
		not coverage is Dictionary
		or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS)
		or not ContractValues.nonnegative_integer_values(coverage, COVERAGE_KEYS)
		or int(coverage.node_count) != int(coverage.typed_node_count) + int(coverage.opaque_node_count)
		or int(coverage.code_bytes) != int(source.code_size)
	):
		return _error("MES inline script name compile coverage changed.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES inline script name compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _find_edited_call(
	code: PackedByteArray,
	analysis: Dictionary,
	operation: Dictionary,
	target: Dictionary
) -> Dictionary:
	var owner_start := int(target.owner_start)
	var owner_end := int(target.owner_end)
	var envelope_start := int(target.envelope_start)
	var envelope_end := int(target.envelope_end)
	var name_start := int(target.name_start)
	var name_end := int(target.name_end)
	if owner_start < 0 or owner_end > code.size() or envelope_end > code.size():
		return _error("Compiled MES inline script byte range is outside the code.")
	if (
		ContractValues.sha256_lenient(code.slice(owner_start, owner_end)) != str(target.replacement_owner_sha256)
		or ContractValues.sha256_lenient(code.slice(envelope_start, envelope_end)) != str(target.replacement_envelope_sha256)
		or ContractValues.sha256_lenient(code.slice(name_start, name_end)) != str(target.replacement_name_sha256)
		or ContractValues.sha256_lenient(code.slice(envelope_start, name_start)) != str(target.prefix_sha256)
		or ContractValues.sha256_lenient(code.slice(name_end, envelope_end)) != str(target.suffix_sha256)
		or code.slice(name_start, name_end).get_string_from_ascii()
		!= str(operation.replacement_name)
	):
		return _error("Compiled MES inline script byte slices differ from their audit.")
	var instruction := MesDecoderScript.new().decode_at(code, envelope_start, envelope_end)
	if (
		not instruction.get("ok", false)
		or str(instruction.get("op", "")) != "inline_script_execution"
		or int(instruction.get("end_offset", -1)) != envelope_end
		or ContractValues.sha256_lenient(str(instruction.get("raw_hex", "")).hex_decode())
		!= str(target.replacement_envelope_sha256)
	):
		return _error("Compiled MES inline script envelope was not exactly redecoded.")
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 1 or not operands[0] is Dictionary:
		return _error("Compiled MES inline script operand was not redecoded.")
	var operand: Dictionary = operands[0]
	if (
		str(operand.get("resource_kind", "")) != "mes_script"
		or int(operand.get("source_offset", -1)) != name_start
		or str(operand.get("source_name", "")) != str(operation.replacement_name)
		or str(operand.get("name", "")) != str(operation.replacement_name).to_upper()
		or int(operand.get("execution_selector", -1)) != int(operation.execution_selector)
		or str(operand.get("execution_role", "")) != str(operation.execution_role)
		or str(operand.get("native_context_restore", "")) != "confirmed"
		or str(operand.get("tool_execution_semantics", "")) != "not_executed"
	):
		return _error("Compiled MES inline script operand differs from its audit.")
	var partition_matches := 0
	var partition_rows: Array = (
		analysis.instructions if str(target.owner_kind) == "statement"
		else analysis.get("opaque_boundaries", [])
	)
	for untyped_row in partition_rows:
		var row: Dictionary = untyped_row
		if (
			int(row.get("source_offset", -1)) == owner_start
			and int(row.get("end_offset", -1)) == owner_end
		):
			partition_matches += 1
	if partition_matches != 1:
		return _error("Compiled MES inline script owner partition was not preserved.")
	var references: Array[Dictionary] = []
	for untyped_reference in analysis.resource_references:
		var reference: Dictionary = untyped_reference
		if (
			int(reference.get("source_offset", -1)) == envelope_start
			and str(reference.get("op", "")) == "inline_script_execution"
			and str(reference.get("resource_kind", "")) == "mes_script"
		):
			references.append(reference)
	if references.size() != 1:
		return _error("Compiled MES inline script reference was not uniquely reindexed.")
	var reference: Dictionary = references[0]
	if (
		str(reference.get("boundary", "")) != str(target.reference_boundary)
		or str(reference.get("source_name", "")) != str(operation.replacement_name)
		or str(reference.get("name", "")) != str(operation.replacement_name).to_upper()
		or reference.get("archive_candidates") != ["mes.arc"]
		or int(reference.get("execution_selector", -1)) != int(operation.execution_selector)
		or str(reference.get("execution_role", "")) != str(operation.execution_role)
		or str(reference.get("native_context_restore", "")) != "confirmed"
		or str(reference.get("tool_execution_semantics", "")) != "not_executed"
	):
		return _error("Compiled MES inline script reference differs from its audit.")
	return {
		"ok": true,
		"call": {
			"op": "inline_script_execution",
			"owner_kind": str(target.owner_kind),
			"owner_start": owner_start,
			"owner_end": owner_end,
			"envelope_start": envelope_start,
			"envelope_end": envelope_end,
			"envelope_sha256": str(target.replacement_envelope_sha256),
			"name_start": name_start,
			"name_end": name_end,
			"name_sha256": str(target.replacement_name_sha256),
			"reference_id": str(operation.reference_id),
			"source_name": str(operation.source_name),
			"replacement_name": str(operation.replacement_name),
			"normalized_name": str(operation.replacement_name).to_upper(),
			"execution_selector": int(operation.execution_selector),
			"execution_role": str(operation.execution_role),
			"reference_boundary": str(target.reference_boundary),
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
