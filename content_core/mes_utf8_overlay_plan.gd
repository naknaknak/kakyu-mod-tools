class_name KakyuMesUtf8OverlayPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "target", "projection_document", "invariants", "payload_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "raw_sha256", "text", "encoding",
	"compatibility", "container_policy",
]
const TARGET_KEYS := [
	"reference_id", "node_id", "region_id", "instruction_start",
	"instruction_end", "payload_start", "payload_end", "source_byte_length",
	"source_raw_sha256",
]
const PROJECTION_KEYS := [
	"schema", "base_archive_sha256", "entry_sha256", "target_archive",
	"target_entry", "edits",
]
const EDIT_KEYS := ["source_offset", "raw_sha256", "text"]
const INVARIANT_KEYS := [
	"source_editable_ir_validated", "target_message_unique_and_typed",
	"source_message_hash_matched", "source_message_strict_cp932",
	"replacement_utf8_valid", "projection_document_ready",
	"mes_container_bytes_not_emitted", "source_container_not_modified",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "remake_only_projection_no_mes_assembly",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "replace_message_utf8_overlay",
	"supported_encoding": "utf8",
	"projection_schema": "kakyu_mes_text_overlay_entry/v1",
	"mes_container_output": "forbidden",
	"original_engine_compatibility": "not_claimed",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_UTF8_OVERLAY_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES UTF-8 overlay plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_utf8_overlay_planner",
		"contract": ContentCoreVersionScript.MES_UTF8_OVERLAY_PLAN_SCHEMA,
	}:
		return _error("MES UTF-8 overlay plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES UTF-8 overlay compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES UTF-8 overlay plan fingerprint changed.")
	var source_identity = document.get("source_identity")
	if (
		not source_identity is Dictionary
		or not ContractValues.has_only_keys(source_identity, SOURCE_IDENTITY_KEYS)
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("archive", "")))
		or not ArcReaderScript.is_safe_entry_name(str(source_identity.get("entry", "")))
		or not ContractValues.is_sha256(str(source_identity.get("archive_sha256", "")))
	):
		return _error("MES UTF-8 overlay source identity is incomplete.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256", "entry_sha256"])
		or not ContractValues.hash_values(inputs, ["editable_ir_sha256", "decompiler_ir_sha256", "entry_sha256"])
	):
		return _error("MES UTF-8 overlay input hashes changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_message_utf8_overlay"
		or str(operation.get("encoding", "")) != "utf8"
		or str(operation.get("compatibility", "")) != "remake_only"
		or str(operation.get("container_policy", "")) != "do_not_assemble_mes"
		or not _nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.is_sha256(str(operation.get("raw_sha256", "")))
		or not operation.get("text") is String
	):
		return _error("MES UTF-8 overlay operation changed.")
	var target = document.get("target")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES UTF-8 overlay target fields changed.")
	if not _integer_values(target, [
		"instruction_start", "instruction_end", "payload_start", "payload_end",
		"source_byte_length",
	]):
		return _error("MES UTF-8 overlay target coordinate changed.")
	if (
		int(target.instruction_start) > int(target.payload_start)
		or int(target.payload_start) > int(target.payload_end)
		or int(target.payload_end) > int(target.instruction_end)
		or int(target.payload_end) - int(target.payload_start) != int(target.source_byte_length)
		or str(target.get("source_raw_sha256", "")) != str(operation.raw_sha256)
	):
		return _error("MES UTF-8 overlay target boundary changed.")
	var projection = document.get("projection_document")
	if not projection is Dictionary or not ContractValues.has_exact_keys(projection, PROJECTION_KEYS):
		return _error("MES UTF-8 overlay projection fields changed.")
	if (
		str(projection.get("schema", "")) != ContentCoreVersionScript.MES_TEXT_OVERLAY_ENTRY_SCHEMA
		or str(projection.get("base_archive_sha256", "")) != str(source_identity.archive_sha256)
		or str(projection.get("entry_sha256", "")) != str(inputs.entry_sha256)
		or str(projection.get("target_archive", "")) != str(source_identity.archive)
		or str(projection.get("target_entry", "")) != str(source_identity.entry)
		or not projection.get("edits") is Array
		or projection.edits.size() != 1
	):
		return _error("MES UTF-8 overlay projection binding changed.")
	var untyped_edit = projection.edits[0]
	if not untyped_edit is Dictionary or not ContractValues.has_exact_keys(untyped_edit, EDIT_KEYS):
		return _error("MES UTF-8 overlay projection edit changed.")
	var edit: Dictionary = untyped_edit
	if (
		not _nonnegative_json_integer(edit.get("source_offset", -1))
		or int(edit.source_offset) != int(operation.source_offset)
		or str(edit.get("raw_sha256", "")) != str(operation.raw_sha256)
		or not edit.get("text") is String
		or str(edit.text) != str(operation.text)
	):
		return _error("MES UTF-8 overlay projection edit disagrees with its operation.")
	var invariants = document.get("invariants")
	if (
		not invariants is Dictionary
		or not ContractValues.has_exact_keys(invariants, INVARIANT_KEYS)
		or not ContractValues.all_true(invariants)
	):
		return _error("MES UTF-8 overlay invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_UTF8_OVERLAY_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"projection_document": projection.duplicate(true),
	}


func _integer_values(document: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not _nonnegative_json_integer(document.get(key, -1)):
			return false
	return true


func _nonnegative_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 0
	return typeof(value) == TYPE_FLOAT and float(value) >= 0.0 and float(value) == floor(float(value))


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
