class_name KakyuMesAddressEntryInsertPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "target", "table_change", "coverage", "assembly_ready",
	"invariants", "payload_sha256",
]
const OPERATION_KEYS := [
	"kind", "owner_entry_index", "target_offset", "instruction_raw_sha256",
]
const TARGET_KEYS := [
	"node_id", "evidence_status", "source_region_id", "source_region_index",
	"source_region_start", "source_region_end", "instruction_start",
	"instruction_end", "instruction_raw_sha256", "op", "command_id",
]
const TABLE_CHANGE_KEYS := [
	"source_entry_count", "output_entry_count", "insertion_index",
	"inserted_offset", "inserted_raw_hex", "previous_entry_offset",
	"next_entry_offset", "source_code_offset", "output_code_offset",
	"source_preamble_sha256", "output_preamble_sha256",
	"source_address_table_sha256", "output_address_table_sha256",
]
const COVERAGE_KEYS := [
	"source_code_size", "output_code_size", "source_node_count",
	"moved_node_count", "moved_reference_count",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "planning_only_insert_one_address_entry_boundary",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "insert_address_entry",
	"target_policy": "strict_typed_instruction_start_inside_existing_entry",
	"bootstrap_policy": "cannot_split_bootstrap",
	"code_coordinate_policy": "unchanged_code_relative_offsets",
	"bytecode_policy": "unchanged",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"source_preamble_rebuilt_exactly": true,
	"target_node_unique_and_typed": true,
	"target_instruction_hash_matched": true,
	"target_is_strictly_inside_source_entry": true,
	"address_offsets_remain_strictly_increasing": true,
	"bytecode_and_code_coordinates_unchanged": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES address-entry insertion plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_address_entry_insert_planner",
		"contract": ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_PLAN_SCHEMA,
	}:
		return _error("MES address-entry insertion plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES address-entry insertion compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES address-entry insertion plan fingerprint changed.")
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
		return _error("MES address-entry insertion source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES address-entry insertion input identity changed.")
	var operation = document.get("operation")
	var target = document.get("target")
	var table_change = document.get("table_change")
	var coverage = document.get("coverage")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES address-entry insertion operation fields changed.")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES address-entry insertion target fields changed.")
	if not table_change is Dictionary or not ContractValues.has_exact_keys(table_change, TABLE_CHANGE_KEYS):
		return _error("MES address-entry insertion table fields changed.")
	if not coverage is Dictionary or not ContractValues.has_exact_keys(coverage, COVERAGE_KEYS):
		return _error("MES address-entry insertion coverage fields changed.")
	var integer_validation := _validate_integers(operation, target, table_change, coverage)
	if not integer_validation.ok:
		return integer_validation
	if (
		str(operation.kind) != "insert_address_entry"
		or not ContractValues.is_sha256(str(operation.instruction_raw_sha256))
		or str(target.node_id).is_empty()
		or str(target.evidence_status) != "typed_phase1_4"
		or str(target.instruction_raw_sha256) != str(operation.instruction_raw_sha256)
		or int(target.source_region_index) != int(operation.owner_entry_index)
		or str(target.source_region_id) != "entry_%04d" % int(operation.owner_entry_index)
		or int(target.instruction_start) != int(operation.target_offset)
		or int(target.instruction_end) <= int(target.instruction_start)
	):
		return _error("MES address-entry insertion typed target identity changed.")
	if (
		int(table_change.source_entry_count) <= 0
		or int(table_change.output_entry_count) != int(table_change.source_entry_count) + 1
		or int(table_change.insertion_index) != int(operation.owner_entry_index) + 1
		or int(table_change.insertion_index) >= int(table_change.output_entry_count)
		or int(table_change.inserted_offset) != int(operation.target_offset)
		or str(table_change.inserted_raw_hex)
		!= ContractValues.u32_hex(int(table_change.inserted_offset))
		or int(table_change.previous_entry_offset) != int(target.source_region_start)
		or int(table_change.next_entry_offset) != int(target.source_region_end)
		or not (
			int(table_change.previous_entry_offset)
			< int(table_change.inserted_offset)
			and int(table_change.inserted_offset)
			< int(table_change.next_entry_offset)
		)
		or int(table_change.source_code_offset)
		!= 4 + int(table_change.source_entry_count) * 4
		or int(table_change.output_code_offset) != int(table_change.source_code_offset) + 4
	):
		return _error("MES address-entry insertion table boundary changed.")
	for key in [
		"source_preamble_sha256", "output_preamble_sha256",
		"source_address_table_sha256", "output_address_table_sha256",
	]:
		if not ContractValues.is_sha256(str(table_change.get(key, ""))):
			return _error("MES address-entry insertion table fingerprint changed.")
	if (
		int(coverage.source_code_size) != int(coverage.output_code_size)
		or int(coverage.source_code_size) <= int(table_change.inserted_offset)
		or int(coverage.source_node_count) <= 0
		or int(coverage.moved_node_count) <= 0
	):
		return _error("MES address-entry insertion coverage changed.")
	if document.get("assembly_ready") != true or document.get("invariants") != INVARIANTS:
		return _error("MES address-entry insertion readiness or invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_ADDRESS_ENTRY_INSERT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"source_entry_count": int(table_change.source_entry_count),
		"output_entry_count": int(table_change.output_entry_count),
		"insertion_index": int(table_change.insertion_index),
		"target_offset": int(table_change.inserted_offset),
		"source_code_offset": int(table_change.source_code_offset),
		"output_code_offset": int(table_change.output_code_offset),
		"mes_bytes": false,
	}


func _validate_integers(
	operation: Dictionary,
	target: Dictionary,
	table_change: Dictionary,
	coverage: Dictionary
) -> Dictionary:
	for key in ["owner_entry_index", "target_offset"]:
		if not _nonnegative_json_integer(operation.get(key, -1)):
			return _error("MES address-entry insertion operation coordinate changed.")
	for key in [
		"source_region_index", "source_region_start", "source_region_end",
		"instruction_start", "instruction_end", "command_id",
	]:
		if not _nonnegative_json_integer(target.get(key, -1)):
			return _error("MES address-entry insertion target coordinate changed.")
	for key in [
		"source_entry_count", "output_entry_count", "insertion_index",
		"inserted_offset", "previous_entry_offset", "next_entry_offset",
		"source_code_offset", "output_code_offset",
	]:
		if not _nonnegative_json_integer(table_change.get(key, -1)):
			return _error("MES address-entry insertion table coordinate changed.")
	for key in COVERAGE_KEYS:
		if not _nonnegative_json_integer(coverage.get(key, -1)):
			return _error("MES address-entry insertion coverage count changed.")
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
