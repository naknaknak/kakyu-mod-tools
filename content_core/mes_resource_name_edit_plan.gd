class_name KakyuMesResourceNameEditPlan
extends RefCounted

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const PLAN_KEYS := [
	"ok", "schema", "producer", "compatibility", "source_identity", "inputs",
	"operation", "target", "replacement", "assembly_ready", "invariants",
	"payload_sha256",
]
const OPERATION_KEYS := [
	"kind", "source_offset", "instruction_raw_sha256", "reference_id", "name",
]
const TARGET_KEYS := [
	"node_id", "region_id", "op", "command_id", "instruction_start",
	"instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
	"reference_id", "reference_boundary", "resource_kind", "archive_candidates",
	"operand_resource_kind", "source_name", "normalized_name", "extension",
	"name_start", "name_end", "name_raw_hex", "name_raw_sha256",
	"prefix_raw_hex", "prefix_raw_sha256", "suffix_raw_hex", "suffix_raw_sha256",
]
const REPLACEMENT_KEYS := [
	"source_name", "normalized_name", "extension", "name_raw_hex",
	"name_raw_sha256", "instruction_raw_hex", "instruction_raw_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const SUPPORTED_RESOURCES := {
	"mmo_resource_marker": {
		# 0x0D framing since Core 0.316.0; formerly a separator plus a 0x09 record.
		"command_id": 13.0,
		"resource_kind": "mmo",
		"operand_resource_kind": "mmo_marker",
		"extensions": ["mmo"],
		"normalization": "identity",
		"prefix_hex": "0d09ff01",
		"suffix_hex": "0000",
	},
	"ax_resource_marker": {
		"command_id": 13.0,
		"resource_kind": "ax",
		"operand_resource_kind": "ax_marker",
		"extensions": ["ax"],
		"normalization": "uppercase_basename_and_extension",
		"prefix_hex": "0d08ff0200ff01",
		"suffix_hex": "000202f900ff00",
	},
	"voice_marker": {
		"command_id": 13.0,
		"resource_kind": "voice",
		"operand_resource_kind": "voice_marker",
		"extensions": ["ogg"],
		"normalization": "uppercase_basename_and_extension",
		"prefix_hex": "0d07ff0202ff01",
		"suffix_hex": "000200ff00",
	},
}
const COMPATIBILITY := {
	"policy": "planning_only_same_length_typed_resource_name_replacement",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "replace_resource_name",
	"supported_resources": SUPPORTED_RESOURCES,
	"selection_policy": "one_exact_strict_indexed_resource_reference",
	"name_policy": "printable_ascii_safe_entry_name_and_matching_extension",
	"length_policy": "replacement_name_must_match_source_byte_length",
	"numeric_operand_policy": "preserve_all_non_name_bytes_without_new_semantic_labels",
	"inline_script_policy": "deferred_to_nested_call_authoring",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"target_node_unique_and_typed": true,
	"source_instruction_hash_matched": true,
	"resource_reference_unique_strict_and_indexed": true,
	"source_name_bytes_match_typed_operand": true,
	"replacement_name_same_length_and_extension": true,
	"prefix_suffix_and_numeric_bytes_unchanged": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_RESOURCE_NAME_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES resource name edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_resource_name_edit_planner",
		"contract": ContentCoreVersionScript.MES_RESOURCE_NAME_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES resource name edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES resource name edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES resource name edit plan fingerprint changed.")
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
		return _error("MES resource name edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES resource name edit input identity changed.")
	var operation = document.get("operation")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES resource name edit operation fields changed.")
	if (
		str(operation.get("kind", "")) != "replace_resource_name"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.is_sha256(str(operation.get("instruction_raw_sha256", "")))
		or str(operation.get("reference_id", "")).is_empty()
		or not ArcReaderScript.is_safe_entry_name(str(operation.get("name", "")))
	):
		return _error("MES resource name edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES resource name edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES resource name edit replacement fields changed.")
	var op := str(target.get("op", ""))
	var form = SUPPORTED_RESOURCES.get(op)
	if (
		not form is Dictionary
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or not ContractValues.nonnegative_json_integer(target.get("command_id", -1))
		or int(target.command_id) != int(form.command_id)
		or str(target.get("resource_kind", "")) != str(form.resource_kind)
		or str(target.get("operand_resource_kind", "")) != str(form.operand_resource_kind)
		or str(target.get("reference_id", "")) != str(operation.reference_id)
		or not ContractValues.json_integer(target.get("instruction_start", -1))
		or int(target.instruction_start) != int(operation.source_offset)
		or str(target.get("instruction_raw_sha256", ""))
		!= str(operation.instruction_raw_sha256)
		or str(replacement.get("source_name", "")) != str(operation.name)
	):
		return _error("MES resource name edit typed target identity changed.")
	var byte_validation := _validate_bytes(target, replacement, form)
	if not byte_validation.ok:
		return byte_validation
	if document.get("assembly_ready") != true:
		return _error("MES resource name edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES resource name edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_RESOURCE_NAME_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"instruction_start": int(target.instruction_start),
		"name_start": int(target.name_start),
		"resource_kind": str(target.resource_kind),
		"source_name": str(target.source_name),
		"replacement_name": str(replacement.source_name),
		"mes_bytes": false,
	}


func _validate_bytes(target: Dictionary, replacement: Dictionary, form: Dictionary) -> Dictionary:
	for key in ["instruction_start", "instruction_end", "name_start", "name_end"]:
		if not ContractValues.nonnegative_json_integer(target.get(key, -1)):
			return _error("MES resource name edit target coordinate changed.")
	if str(target.get("reference_boundary", "")) != "strict_indexed":
		return _error("MES resource name edit reference boundary changed.")
	var archives = target.get("archive_candidates")
	if not archives is Array or archives.is_empty():
		return _error("MES resource name edit archive candidates changed.")
	for archive in archives:
		if not ArcReaderScript.is_safe_entry_name(str(archive)):
			return _error("MES resource name edit archive candidates changed.")
	var source_instruction := _decode_hex(str(target.get("instruction_raw_hex", "")), false)
	var source_name_raw := _decode_hex(str(target.get("name_raw_hex", "")), false)
	var prefix := _decode_hex(str(target.get("prefix_raw_hex", "")), true)
	var suffix := _decode_hex(str(target.get("suffix_raw_hex", "")), true)
	var output_name_raw := _decode_hex(str(replacement.get("name_raw_hex", "")), false)
	var output_instruction := _decode_hex(str(replacement.get("instruction_raw_hex", "")), false)
	if (
		source_instruction.is_empty()
		or source_name_raw.is_empty()
		or output_name_raw.is_empty()
		or output_instruction.is_empty()
	):
		return _error("MES resource name edit planned bytes changed.")
	var rows := [
		[target, source_instruction, "instruction"],
		[target, source_name_raw, "name"],
		[target, prefix, "prefix"],
		[target, suffix, "suffix"],
		[replacement, output_name_raw, "name"],
		[replacement, output_instruction, "instruction"],
	]
	for row in rows:
		if ContractValues.sha256_lenient(row[1]) != str(row[0].get("%s_raw_sha256" % row[2], "")):
			return _error("MES resource name edit planned hash changed.")
	var instruction_start := int(target.instruction_start)
	var instruction_end := int(target.instruction_end)
	var name_start := int(target.name_start)
	var name_end := int(target.name_end)
	if (
		instruction_end <= instruction_start
		or name_start < instruction_start
		or name_end <= name_start
		or name_end > instruction_end
		or instruction_end - instruction_start != source_instruction.size()
		or name_end - name_start != source_name_raw.size()
		or source_name_raw.size() != output_name_raw.size()
		or source_instruction != _join_bytes(prefix, source_name_raw, suffix)
		or output_instruction != _join_bytes(prefix, output_name_raw, suffix)
		or source_instruction.size() != output_instruction.size()
		or prefix.hex_encode() != str(form.prefix_hex)
		or suffix.hex_encode() != str(form.suffix_hex)
	):
		return _error("MES resource name edit planned boundary changed.")
	var source_name := _ascii_name(source_name_raw)
	var output_name := _ascii_name(output_name_raw)
	if (
		source_name.is_empty()
		or output_name.is_empty()
		or source_name != str(target.get("source_name", ""))
		or source_name.get_extension().to_lower() != str(target.get("extension", ""))
		or _normalize_name(source_name, form) != str(target.get("normalized_name", ""))
		or output_name != str(replacement.get("source_name", ""))
		or output_name.get_extension().to_lower() != str(replacement.get("extension", ""))
		or _normalize_name(output_name, form) != str(replacement.get("normalized_name", ""))
		or source_name.get_extension().to_lower() not in form.extensions
		or output_name.get_extension().to_lower() not in form.extensions
	):
		return _error("MES resource name edit planned name changed.")
	return {"ok": true}


func _ascii_name(raw: PackedByteArray) -> String:
	for value in raw:
		if value < 0x20 or value > 0x7E:
			return ""
	var value := raw.get_string_from_ascii()
	return value if ArcReaderScript.is_safe_entry_name(value) else ""


func _normalize_name(value: String, form: Dictionary) -> String:
	if str(form.normalization) == "identity":
		return value
	return value.get_basename().to_upper() + "." + value.get_extension().to_upper()


func _join_bytes(prefix: PackedByteArray, middle: PackedByteArray, suffix: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(prefix)
	result.append_array(middle)
	result.append_array(suffix)
	return result


func _decode_hex(value: String, allow_empty: bool) -> PackedByteArray:
	if (value.is_empty() and not allow_empty) or value.length() % 2 != 0:
		return PackedByteArray()
	for character in value:
		if character not in "0123456789abcdef":
			return PackedByteArray()
	return value.hex_decode()


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
