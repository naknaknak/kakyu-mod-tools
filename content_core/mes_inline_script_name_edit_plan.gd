class_name KakyuMesInlineScriptNameEditPlan
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
	"kind", "source_offset", "owner_raw_sha256", "reference_id", "name",
]
const TARGET_KEYS := [
	"node_id", "region_id", "owner_kind", "owner_start", "owner_end",
	"owner_raw_sha256", "op", "command_id", "envelope_start", "envelope_end",
	"envelope_raw_hex", "envelope_raw_sha256", "reference_id",
	"reference_boundary", "resource_kind", "archive_candidates", "source_name",
	"normalized_name", "extension", "execution_selector", "execution_role",
	"native_context_restore", "tool_execution_semantics", "name_start",
	"name_end", "name_raw_hex", "name_raw_sha256", "prefix_raw_hex",
	"prefix_raw_sha256", "suffix_raw_hex", "suffix_raw_sha256",
]
const REPLACEMENT_KEYS := [
	"source_name", "normalized_name", "extension", "name_raw_hex",
	"name_raw_sha256", "envelope_raw_hex", "envelope_raw_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const SUPPORTED_SELECTORS := {
	"2": {"extension": "lib", "role": "library_bootstrap"},
	"3": {"extension": "mes", "role": "definition_bootstrap"},
}
const COMPATIBILITY := {
	"policy": "planning_only_same_length_bounded_inline_script_name_replacement",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "replace_inline_script_name",
	"supported_selectors": SUPPORTED_SELECTORS,
	"selection_policy": "one_exact_indexed_inline_script_reference",
	"boundary_policy": "typed_instruction_or_bounded_envelope_inside_one_opaque_owner",
	"name_policy": "printable_ascii_safe_entry_name_and_selector_extension",
	"length_policy": "replacement_name_must_match_source_byte_length",
	"context_policy": "preserve_selector_role_restore_and_all_non_name_bytes",
	"resource_existence": "not_checked",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"target_owner_unique_and_source_bound": true,
	"indexed_reference_exact": true,
	"inline_envelope_exact_and_bounded": true,
	"selector_role_and_extension_matched": true,
	"replacement_name_same_length": true,
	"owner_bytes_outside_name_unchanged": true,
	"opaque_owner_boundary_preserved": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES inline script name edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_inline_script_name_edit_planner",
		"contract": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES inline script name edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES inline script name edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES inline script name edit plan fingerprint changed.")
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
		return _error("MES inline script name edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.hash_values(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
	):
		return _error("MES inline script name edit input identity changed.")
	var operation = document.get("operation")
	if (
		not operation is Dictionary
		or not ContractValues.has_exact_keys(operation, OPERATION_KEYS)
		or str(operation.get("kind", "")) != "replace_inline_script_name"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.is_sha256(str(operation.get("owner_raw_sha256", "")))
		or str(operation.get("reference_id", "")).is_empty()
		or not ArcReaderScript.is_safe_entry_name(str(operation.get("name", "")))
	):
		return _error("MES inline script name edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES inline script name edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES inline script name edit replacement fields changed.")
	if (
		str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("op", "")) != "inline_script_execution"
		or not ContractValues.nonnegative_json_integer(target.get("command_id", -1))
		or int(target.command_id) != 0x0D
		or str(target.get("owner_raw_sha256", "")) != str(operation.owner_raw_sha256)
		or str(target.get("reference_id", "")) != str(operation.reference_id)
		or not ContractValues.nonnegative_json_integer(target.get("envelope_start", -1))
		or int(target.envelope_start) != int(operation.source_offset)
		or str(replacement.get("source_name", "")) != str(operation.name)
	):
		return _error("MES inline script name edit target identity changed.")
	var bytes_validation := _validate_bytes(target, replacement)
	if not bytes_validation.ok:
		return bytes_validation
	if document.get("assembly_ready") != true:
		return _error("MES inline script name edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES inline script name edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_INLINE_SCRIPT_NAME_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"envelope_start": int(target.envelope_start),
		"name_start": int(target.name_start),
		"owner_kind": str(target.owner_kind),
		"reference_boundary": str(target.reference_boundary),
		"execution_selector": int(target.execution_selector),
		"source_name": str(target.source_name),
		"replacement_name": str(replacement.source_name),
		"mes_bytes": false,
	}


func _validate_bytes(target: Dictionary, replacement: Dictionary) -> Dictionary:
	for key in [
		"owner_start", "owner_end", "envelope_start", "envelope_end",
		"name_start", "name_end", "execution_selector",
	]:
		if not ContractValues.nonnegative_json_integer(target.get(key, -1)):
			return _error("MES inline script name edit target coordinate changed.")
	var selector := int(target.execution_selector)
	var form = SUPPORTED_SELECTORS.get(str(selector))
	var owner_kind := str(target.get("owner_kind", ""))
	var expected_boundary := (
		"strict_indexed" if owner_kind == "statement"
		else "bounded_envelope_scan" if owner_kind == "opaque"
		else ""
	)
	if (
		not form is Dictionary
		or str(target.get("reference_boundary", "")) != expected_boundary
		or str(target.get("resource_kind", "")) != "mes_script"
		or target.get("archive_candidates") != ["mes.arc"]
		or str(target.get("execution_role", "")) != str(form.role)
		or str(target.get("extension", "")) != str(form.extension)
		or str(target.get("native_context_restore", "")) != "confirmed"
		or str(target.get("tool_execution_semantics", "")) != "not_executed"
	):
		return _error("MES inline script name edit selector or boundary changed.")
	var envelope := ContractValues.decode_hex(str(target.get("envelope_raw_hex", "")))
	var source_name_raw := ContractValues.decode_hex(str(target.get("name_raw_hex", "")))
	var prefix := ContractValues.decode_hex(str(target.get("prefix_raw_hex", "")))
	var suffix := ContractValues.decode_hex(str(target.get("suffix_raw_hex", "")))
	var output_name_raw := ContractValues.decode_hex(str(replacement.get("name_raw_hex", "")))
	var output_envelope := ContractValues.decode_hex(str(replacement.get("envelope_raw_hex", "")))
	if (
		envelope.is_empty() or source_name_raw.is_empty() or prefix.is_empty()
		or suffix.is_empty() or output_name_raw.is_empty() or output_envelope.is_empty()
	):
		return _error("MES inline script name edit planned bytes changed.")
	for row in [
		[target, envelope, "envelope_raw_sha256"],
		[target, source_name_raw, "name_raw_sha256"],
		[target, prefix, "prefix_raw_sha256"],
		[target, suffix, "suffix_raw_sha256"],
		[replacement, output_name_raw, "name_raw_sha256"],
		[replacement, output_envelope, "envelope_raw_sha256"],
	]:
		if ContractValues.sha256_lenient(row[1]) != str(row[0].get(row[2], "")):
			return _error("MES inline script name edit planned hash changed.")
	var owner_start := int(target.owner_start)
	var owner_end := int(target.owner_end)
	var envelope_start := int(target.envelope_start)
	var envelope_end := int(target.envelope_end)
	var name_start := int(target.name_start)
	var name_end := int(target.name_end)
	var expected_prefix := ("0d08ff02%02xff01" % selector).hex_decode()
	if (
		owner_end <= owner_start
		or envelope_start < owner_start or envelope_end > owner_end
		or envelope_end <= envelope_start
		or name_start != envelope_start + prefix.size()
		or name_end != name_start + source_name_raw.size()
		or envelope_end != name_end + suffix.size()
		or envelope != _join(prefix, source_name_raw, suffix)
		or output_envelope != _join(prefix, output_name_raw, suffix)
		or source_name_raw.size() != output_name_raw.size()
		or envelope.size() != output_envelope.size()
		or prefix != expected_prefix
		or suffix != PackedByteArray([0, 0])
	):
		return _error("MES inline script name edit planned envelope boundary changed.")
	var source_name := _ascii_name(source_name_raw)
	var output_name := _ascii_name(output_name_raw)
	if (
		source_name.is_empty() or output_name.is_empty()
		or source_name != str(target.get("source_name", ""))
		or source_name.to_upper() != str(target.get("normalized_name", ""))
		or output_name != str(replacement.get("source_name", ""))
		or output_name.to_upper() != str(replacement.get("normalized_name", ""))
		or source_name.get_extension().to_lower() != str(form.extension)
		or output_name.get_extension().to_lower() != str(form.extension)
		or str(replacement.get("extension", "")) != str(form.extension)
	):
		return _error("MES inline script name edit planned name changed.")
	return {"ok": true}


func _ascii_name(raw: PackedByteArray) -> String:
	for value in raw:
		if value < 0x20 or value > 0x7E:
			return ""
	var value := raw.get_string_from_ascii()
	return value if ArcReaderScript.is_safe_entry_name(value) else ""


func _join(prefix: PackedByteArray, middle: PackedByteArray, suffix: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.append_array(prefix)
	result.append_array(middle)
	result.append_array(suffix)
	return result


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
