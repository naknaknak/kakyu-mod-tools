class_name KakyuMesAddressEntryInsertCompileReopen
extends RefCounted

const AnalyzerHandoffScript := preload("res://content_core/mes_analyzer_handoff.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const PlanScript := preload("res://content_core/mes_address_entry_insert_plan.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const AUDIT_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "target", "table_change", "source", "output", "coverage",
	"invariants", "payload_sha256",
]
const CONTAINER_KEYS := [
	"size", "entry_count", "code_offset", "code_size", "entry_sha256",
	"bytecode_sha256", "preamble_sha256", "address_table_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "exact_address_entry_insert_plan_new_file_only",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"input_plan_schema": "kakyu_mes_address_entry_insert_plan/v1",
	"output_policy": "new_file_only",
	"bytecode_policy": "byte_identical",
	"code_coordinate_policy": "unchanged",
	"native_engine_compatibility": "unverified",
	"unknown_audit_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"entry_insert_plan_validated": true,
	"source_container_reconstructed_exactly": true,
	"output_container_reopened": true,
	"entry_count_incremented_once": true,
	"address_table_cell_inserted_exactly": true,
	"address_offsets_strictly_increasing": true,
	"bytecode_byte_identical": true,
	"code_coordinates_unchanged": true,
	"source_buffer_not_modified": true,
	"output_published_exclusively": true,
	"audit_published_after_output": true,
}


func audit(payload: PackedByteArray, compile_audit: Dictionary) -> Dictionary:
	var audit_validation := validate_compile_audit(compile_audit)
	if not audit_validation.ok:
		return audit_validation
	var source_identity: Dictionary = compile_audit.source_identity.duplicate(true)
	var document := MesContainerScript.new().parse(payload, source_identity)
	if not document.get("ok", false):
		return _error("Compiled address-entry MES container could not be reopened.")
	var output: Dictionary = compile_audit.output
	var code_offset := int(document.header.code_offset)
	if (
		payload.size() != int(output.size)
		or int(document.header.entry_count) != int(output.entry_count)
		or code_offset != int(output.code_offset)
		or int(document.header.code_size) != int(output.code_size)
		or ContractValues.sha256_lenient(payload) != str(output.entry_sha256)
		or ContractValues.sha256_lenient(document.bytecode) != str(output.bytecode_sha256)
		or ContractValues.sha256_lenient(payload.slice(0, code_offset)) != str(output.preamble_sha256)
		or ContractValues.sha256_lenient(payload.slice(4, code_offset)) != str(output.address_table_sha256)
	):
		return _error("GDScript address-entry MES reopen differs from the compile audit.")
	var table: Dictionary = compile_audit.table_change
	var insertion_index := int(table.insertion_index)
	var entries: Array = document.entries
	if (
		insertion_index <= 0
		or insertion_index >= entries.size()
		or int(entries[insertion_index].offset) != int(table.inserted_offset)
		or int(entries[insertion_index - 1].offset) != int(table.previous_entry_offset)
		or int(entries[insertion_index - 1].end_offset) != int(table.inserted_offset)
		or int(entries[insertion_index].end_offset) != int(table.next_entry_offset)
	):
		return _error("GDScript address-entry MES region split changed.")
	var analysis := MesAnalysisScript.new().build(document)
	if not analysis.get("ok", false):
		return _error("Compiled address-entry MES Phase 1-4 analysis failed.")
	var handoff_builder := AnalyzerHandoffScript.new()
	var handoff := handoff_builder.build(document, analysis)
	var verified: Dictionary = handoff_builder.verify(handoff)
	if not verified.ok:
		return _error("Compiled address-entry MES analyzer handoff failed: %s" % verified.get("error", "unknown error"))
	if handoff.source_identity != source_identity:
		return _error("Compiled address-entry MES source identity changed during reopen.")
	var instructions: Array = handoff.typed_ir.instructions
	var opaque: Array = handoff.typed_ir.opaque_boundaries
	if instructions.size() + opaque.size() != int(compile_audit.coverage.source_node_count):
		return _error("Compiled address-entry MES node partition changed.")
	var target_matches: Array[Dictionary] = []
	for untyped_instruction in instructions:
		var instruction: Dictionary = untyped_instruction
		if int(instruction.source_offset) == int(table.inserted_offset):
			target_matches.append(instruction)
	if target_matches.size() != 1:
		return _error("Compiled address-entry MES target is not one typed instruction.")
	var target_instruction := target_matches[0]
	var target: Dictionary = compile_audit.target
	if (
		str(target_instruction.region) != "entry_%04d" % insertion_index
		or int(target_instruction.end_offset) != int(target.instruction_end)
		or int(target_instruction.command_id) != int(target.command_id)
		or str(target_instruction.op) != str(target.op)
		or ContractValues.sha256_lenient(document.bytecode.slice(
			int(target_instruction.source_offset), int(target_instruction.end_offset)
		)) != str(target.instruction_raw_sha256)
	):
		return _error("Compiled address-entry MES target instruction changed.")
	var result := {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_REOPEN_AUDIT_SCHEMA,
		"producer": {
			"implementation": "godot_gdscript_phase1_4_address_entry_insert_reopen",
			"contract": ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_REOPEN_AUDIT_SCHEMA,
		},
		"source_identity": compile_audit.source_identity.duplicate(true),
		"compile_audit_sha256": str(compile_audit.payload_sha256),
		"output": output.duplicate(true),
		"table_change": table.duplicate(true),
		"target": {
			"node_id": "instruction_%08x" % int(target_instruction.source_offset),
			"region": str(target_instruction.region),
			"instruction_start": int(target_instruction.source_offset),
			"instruction_end": int(target_instruction.end_offset),
			"instruction_raw_sha256": ContractValues.sha256_lenient(document.bytecode.slice(
				int(target_instruction.source_offset), int(target_instruction.end_offset)
			)),
		},
		"phase1_4": {
			"handoff_sha256": str(handoff.payload_sha256),
			"analysis_complete": bool(analysis.complete),
			"analysis_diagnostic_count": int(analysis.diagnostic_count),
			"typed_node_count": instructions.size(),
			"opaque_node_count": opaque.size(),
		},
		"invariants": {
			"compile_audit_fingerprint_valid": true,
			"output_hashes_match": true,
			"entry_count_incremented_once": true,
			"inserted_cell_and_region_split_exact": true,
			"bytecode_hash_unchanged": str(compile_audit.source.bytecode_sha256) == str(output.bytecode_sha256),
			"source_node_partition_preserved": true,
			"target_reindexed_as_new_entry_intro": true,
			"handoff_rebuilt_and_verified": true,
		},
	}
	result["payload_sha256"] = fingerprint(result)
	return result


func validate_compile_audit(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_COMPILE_AUDIT_SCHEMA
		or not ContractValues.has_exact_keys(document, AUDIT_KEYS)
	):
		return _error("MES address-entry insertion compile audit schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_address_entry_insert_compiler",
		"contract": ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_COMPILE_AUDIT_SCHEMA,
	}:
		return _error("MES address-entry insertion compile producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES address-entry insertion compile compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or fingerprint(document) != retained_hash:
		return _error("MES address-entry insertion compile fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or (
			source_identity.has("archive_sha256")
			and not ContractValues.is_sha256(str(source_identity.archive_sha256))
		)
	):
		return _error("MES address-entry insertion compile source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, [
			"editable_ir_sha256", "decompiler_ir_sha256",
			"address_entry_insert_plan_sha256",
		])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES address-entry insertion compile input identity changed.")
	var operation = document.get("operation")
	var target = document.get("target")
	var table = document.get("table_change")
	var coverage = document.get("coverage")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, PlanScript.OPERATION_KEYS):
		return _error("MES address-entry insertion compile operation fields changed.")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, PlanScript.TARGET_KEYS):
		return _error("MES address-entry insertion compile target fields changed.")
	if not table is Dictionary or not ContractValues.has_exact_keys(table, PlanScript.TABLE_CHANGE_KEYS):
		return _error("MES address-entry insertion compile table fields changed.")
	if not coverage is Dictionary or not ContractValues.has_exact_keys(coverage, PlanScript.COVERAGE_KEYS):
		return _error("MES address-entry insertion compile coverage fields changed.")
	var component_validation := _validate_plan_components(operation, target, table, coverage)
	if not component_validation.ok:
		return component_validation
	var source = document.get("source")
	var output = document.get("output")
	if not source is Dictionary or not ContractValues.has_exact_keys(source, CONTAINER_KEYS):
		return _error("MES address-entry insertion compile source summary changed.")
	if not output is Dictionary or not ContractValues.has_exact_keys(output, CONTAINER_KEYS):
		return _error("MES address-entry insertion compile output summary changed.")
	for summary in [source, output]:
		var summary_validation := _validate_container_summary(summary)
		if not summary_validation.ok:
			return summary_validation
	if (
		int(output.entry_count) != int(source.entry_count) + 1
		or int(output.code_offset) != int(source.code_offset) + 4
		or int(output.code_size) != int(source.code_size)
		or str(output.bytecode_sha256) != str(source.bytecode_sha256)
		or int(output.entry_count) != int(table.output_entry_count)
		or int(output.code_offset) != int(table.output_code_offset)
		or str(output.preamble_sha256) != str(table.output_preamble_sha256)
		or str(output.address_table_sha256) != str(table.output_address_table_sha256)
	):
		return _error("MES address-entry insertion compile geometry changed.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES address-entry insertion compile invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_COMPILE_AUDIT_SCHEMA,
		"payload_sha256": retained_hash,
	}


func fingerprint(document: Dictionary) -> String:
	return FingerprintScript.new().fingerprint(document)


func _validate_plan_components(
	operation: Dictionary,
	target: Dictionary,
	table: Dictionary,
	coverage: Dictionary
) -> Dictionary:
	for key in ["owner_entry_index", "target_offset"]:
		if not _nonnegative_json_integer(operation.get(key, -1)):
			return _error("MES address-entry insertion compile operation coordinate changed.")
	for key in [
		"source_region_index", "source_region_start", "source_region_end",
		"instruction_start", "instruction_end", "command_id",
	]:
		if not _nonnegative_json_integer(target.get(key, -1)):
			return _error("MES address-entry insertion compile target coordinate changed.")
	for key in [
		"source_entry_count", "output_entry_count", "insertion_index",
		"inserted_offset", "previous_entry_offset", "next_entry_offset",
		"source_code_offset", "output_code_offset",
	]:
		if not _nonnegative_json_integer(table.get(key, -1)):
			return _error("MES address-entry insertion compile table coordinate changed.")
	for key in PlanScript.COVERAGE_KEYS:
		if not _nonnegative_json_integer(coverage.get(key, -1)):
			return _error("MES address-entry insertion compile coverage changed.")
	if (
		str(operation.get("kind", "")) != "insert_address_entry"
		or not ContractValues.is_sha256(str(operation.get("instruction_raw_sha256", "")))
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("evidence_status", "")) != "typed_phase1_4"
		or int(target.source_region_index) != int(operation.owner_entry_index)
		or str(target.source_region_id) != "entry_%04d" % int(operation.owner_entry_index)
		or int(target.source_region_start) != int(table.previous_entry_offset)
		or int(target.source_region_end) != int(table.next_entry_offset)
		or int(target.instruction_start) != int(operation.target_offset)
		or int(target.instruction_end) <= int(target.instruction_start)
		or str(target.instruction_raw_sha256) != str(operation.instruction_raw_sha256)
		or int(table.source_entry_count) <= 0
		or int(table.output_entry_count) != int(table.source_entry_count) + 1
		or int(table.insertion_index) != int(operation.owner_entry_index) + 1
		or int(table.insertion_index) >= int(table.output_entry_count)
		or int(table.inserted_offset) != int(operation.target_offset)
		or str(table.inserted_raw_hex) != ContractValues.u32_hex(int(table.inserted_offset))
		or not (int(table.previous_entry_offset) < int(table.inserted_offset) and int(table.inserted_offset) < int(table.next_entry_offset))
		or int(table.source_code_offset) != 4 + int(table.source_entry_count) * 4
		or int(table.output_code_offset) != int(table.source_code_offset) + 4
		or int(coverage.source_code_size) != int(coverage.output_code_size)
		or int(coverage.source_code_size) <= int(table.inserted_offset)
		or int(coverage.source_node_count) <= 0
		or int(coverage.moved_node_count) <= 0
	):
		return _error("MES address-entry insertion compile plan boundary changed.")
	for key in [
		"source_preamble_sha256", "output_preamble_sha256",
		"source_address_table_sha256", "output_address_table_sha256",
	]:
		if not ContractValues.is_sha256(str(table.get(key, ""))):
			return _error("MES address-entry insertion compile table hash changed.")
	return {"ok": true}


func _validate_container_summary(summary: Dictionary) -> Dictionary:
	for key in ["size", "entry_count", "code_offset", "code_size"]:
		if not _nonnegative_json_integer(summary.get(key, -1)):
			return _error("MES address-entry insertion compile container count changed.")
	if (
		int(summary.code_offset) != 4 + int(summary.entry_count) * 4
		or int(summary.size) != int(summary.code_offset) + int(summary.code_size)
	):
		return _error("MES address-entry insertion compile container size changed.")
	for key in [
		"entry_sha256", "bytecode_sha256", "preamble_sha256",
		"address_table_sha256",
	]:
		if not ContractValues.is_sha256(str(summary.get(key, ""))):
			return _error("MES address-entry insertion compile container hash changed.")
	return {"ok": true}


func _nonnegative_json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and float(value) >= 0.0
		and float(value) <= 4294967295.0
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
