class_name KakyuMesStateLiteralEditPlan
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
	"kind", "source_offset", "instruction_raw_sha256", "pair_index", "value",
]
const TARGET_KEYS := [
	"node_id", "region_id", "op", "command_id", "instruction_start",
	"instruction_end", "instruction_raw_hex", "instruction_raw_sha256", "storage",
	"destination", "pair_index", "pair_count", "continuation_offset", "continuation",
	"expression_start", "expression_end", "expression_raw_hex",
	"expression_raw_sha256", "value", "width",
]
const REPLACEMENT_KEYS := [
	"value", "width", "expression_raw_hex", "expression_raw_sha256",
	"instruction_raw_hex", "instruction_raw_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const SUPPORTED_WRITES := {
	"global_u8_write_run": {"command_id": 3.0, "storage": "global_u8"},
	"state_u16_write_run": {"command_id": 4.0, "storage": "state_u16"},
	"banked_u8_write_run": {"command_id": 6.0, "storage": "banked_u8"},
	"banked_u16_write_run": {"command_id": 7.0, "storage": "banked_u16"},
	"banked_i32_write_run": {"command_id": 8.0, "storage": "banked_i32"},
	"global_i32_write_run": {"command_id": 10.0, "storage": "global_i32"},
}
const WRITE_DESTINATION_KINDS := {
	"global_u8_write_run": "fixed_index",
	"state_u16_write_run": "fixed_index",
	"banked_u8_write_run": "expression_index",
	"banked_u16_write_run": "expression_index",
	"banked_i32_write_run": "expression_index",
	"global_i32_write_run": "expression_index",
}
const COMPATIBILITY := {
	"policy": "planning_only_same_width_literal_expression_replacement",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "replace_state_write_literal",
	"supported_writes": SUPPORTED_WRITES,
	"supported_literal_widths": [8.0, 16.0, 32.0],
	"u8_literal_policy": "unambiguous_token_00_through_7f_only",
	"expression_shape_policy": "single_literal_only",
	"length_policy": "replacement_expression_must_match_source_length",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"target_node_unique_and_typed": true,
	"source_instruction_hash_matched": true,
	"source_expression_is_exact_literal": true,
	"replacement_expression_same_width_and_length": true,
	"continuation_byte_unchanged": true,
	"all_other_instruction_bytes_unchanged": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", "")) != ContentCoreVersionScript.MES_STATE_LITERAL_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES state literal edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_state_literal_edit_planner",
		"contract": ContentCoreVersionScript.MES_STATE_LITERAL_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES state literal edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES state literal edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES state literal edit plan fingerprint changed.")
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
		return _error("MES state literal edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES state literal edit input identity changed.")
	var operation = document.get("operation")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES state literal edit operation fields changed.")
	if (
		str(operation.get("kind", "")) != "replace_state_write_literal"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.is_sha256(str(operation.get("instruction_raw_sha256", "")))
		or not ContractValues.nonnegative_json_integer(operation.get("pair_index", -1))
		or not ContractValues.nonnegative_json_integer(operation.get("value", -1))
	):
		return _error("MES state literal edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES state literal edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES state literal edit replacement fields changed.")
	var write_form: Dictionary = SUPPORTED_WRITES.get(str(target.get("op", "")), {})
	if (
		write_form.is_empty()
		or str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or not ContractValues.nonnegative_json_integer(target.get("command_id", -1))
		or int(target.command_id) != int(write_form.command_id)
		or str(target.get("storage", "")) != str(write_form.storage)
		or str(target.get("instruction_raw_sha256", "")) != str(operation.instruction_raw_sha256)
		or not ContractValues.json_integer(target.get("pair_index", -1))
		or int(target.pair_index) != int(operation.pair_index)
		or not ContractValues.json_integer(replacement.get("value", -1))
		or int(replacement.value) != int(operation.value)
	):
		return _error("MES state literal edit typed target identity changed.")
	var destination_validation := _validate_destination(target.get("destination"))
	if not destination_validation.ok:
		return destination_validation
	var destination: Dictionary = target.destination
	if (
		str(destination.get("kind", "")) != str(WRITE_DESTINATION_KINDS.get(str(target.op), ""))
		or (
			str(target.op) in ["global_u8_write_run", "state_u16_write_run", "global_i32_write_run"]
			and int(destination.get("bank", -1)) != 0
		)
	):
		return _error("MES state literal edit destination does not match its write form.")
	var byte_validation := _validate_bytes(target, replacement)
	if not byte_validation.ok:
		return byte_validation
	if document.get("assembly_ready") != true:
		return _error("MES state literal edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES state literal edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_STATE_LITERAL_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"storage": str(target.storage),
		"instruction_start": int(target.instruction_start),
		"width": int(target.width),
		"source_value": int(target.value),
		"replacement_value": int(replacement.value),
		"mes_bytes": false,
	}


func _validate_destination(untyped_destination: Variant) -> Dictionary:
	if not untyped_destination is Dictionary:
		return _error("MES state literal edit destination changed.")
	var destination: Dictionary = untyped_destination
	var kind := str(destination.get("kind", ""))
	if kind == "fixed_index":
		if (
			not ContractValues.has_exact_keys(destination, ["kind", "index", "bank"])
			or not ContractValues.nonnegative_json_integer(destination.get("index", -1))
			or not _byte_json_integer(destination.get("bank", -1))
		):
			return _error("MES state literal edit fixed destination changed.")
		return {"ok": true}
	if kind == "expression_index":
		if (
			not ContractValues.has_exact_keys(destination, [
				"kind", "expression_raw_hex", "expression_raw_sha256", "bank",
			])
			or not _byte_json_integer(destination.get("bank", -1))
		):
			return _error("MES state literal edit expression destination changed.")
		var raw := ContractValues.decode_hex(str(destination.get("expression_raw_hex", "")))
		if raw.is_empty() or ContractValues.sha256_lenient(raw) != str(destination.get("expression_raw_sha256", "")):
			return _error("MES state literal edit destination hash changed.")
		return {"ok": true}
	return _error("MES state literal edit destination form is unsupported.")


func _validate_bytes(target: Dictionary, replacement: Dictionary) -> Dictionary:
	for key in [
		"command_id", "instruction_start", "instruction_end", "pair_index", "pair_count",
		"continuation_offset", "continuation", "expression_start", "expression_end",
		"value", "width",
	]:
		if not ContractValues.nonnegative_json_integer(target.get(key, -1)):
			return _error("MES state literal edit target coordinate changed.")
	if (
		not ContractValues.nonnegative_json_integer(replacement.get("value", -1))
		or not ContractValues.nonnegative_json_integer(replacement.get("width", -1))
	):
		return _error("MES state literal edit replacement value changed.")
	var instruction_start := int(target.instruction_start)
	var instruction_end := int(target.instruction_end)
	var expression_start := int(target.expression_start)
	var expression_end := int(target.expression_end)
	if (
		instruction_end <= instruction_start
		or expression_start < instruction_start
		or expression_end >= instruction_end
		or int(target.pair_count) <= 0
		or int(target.pair_index) >= int(target.pair_count)
		or int(target.continuation) > 0xFF
		or int(target.continuation_offset) != expression_end
		or int(target.width) != int(replacement.width)
	):
		return _error("MES state literal edit target boundary changed.")
	var source_instruction := ContractValues.decode_hex(str(target.instruction_raw_hex))
	var source_expression := ContractValues.decode_hex(str(target.expression_raw_hex))
	var output_instruction := ContractValues.decode_hex(str(replacement.instruction_raw_hex))
	var output_expression := ContractValues.decode_hex(str(replacement.expression_raw_hex))
	if (
		source_instruction.is_empty()
		or source_expression.is_empty()
		or output_instruction.is_empty()
		or output_expression.is_empty()
		or source_instruction.size() != output_instruction.size()
		or source_expression.size() != output_expression.size()
		or instruction_end - instruction_start != source_instruction.size()
		or expression_end - expression_start != source_expression.size()
		or int(source_instruction[0]) != int(target.command_id)
	):
		return _error("MES state literal edit planned length changed.")
	if (
		ContractValues.sha256_lenient(source_instruction) != str(target.instruction_raw_sha256)
		or ContractValues.sha256_lenient(source_expression) != str(target.expression_raw_sha256)
		or ContractValues.sha256_lenient(output_instruction) != str(replacement.instruction_raw_sha256)
		or ContractValues.sha256_lenient(output_expression) != str(replacement.expression_raw_sha256)
	):
		return _error("MES state literal edit planned hash changed.")
	var expected_source_expression := _encode_literal(int(target.value), int(target.width))
	var expected_output_expression := _encode_literal(int(replacement.value), int(replacement.width))
	if (
		expected_source_expression.is_empty()
		or expected_output_expression.is_empty()
		or source_expression != expected_source_expression
		or output_expression != expected_output_expression
	):
		return _error("MES state literal edit literal encoding changed.")
	var relative_start := expression_start - instruction_start
	var relative_end := expression_end - instruction_start
	if (
		source_instruction.slice(relative_start, relative_end) != source_expression
		or int(source_instruction[relative_end]) != int(target.continuation)
	):
		return _error("MES state literal edit source placement changed.")
	var expected_output := PackedByteArray()
	expected_output.append_array(source_instruction.slice(0, relative_start))
	expected_output.append_array(output_expression)
	expected_output.append_array(source_instruction.slice(relative_end))
	if expected_output != output_instruction:
		return _error("MES state literal edit replacement touched unrelated bytes.")
	return {"ok": true}


func _encode_literal(value: int, width: int) -> PackedByteArray:
	if value < 0:
		return PackedByteArray()
	if width == 8:
		return PackedByteArray([value, 0xFF]) if value <= 0x7F else PackedByteArray()
	var output := PackedByteArray()
	if width == 16 and value <= 0xFFFF:
		output.append(0xF1)
		output.append(value & 0xFF)
		output.append((value >> 8) & 0xFF)
		output.append(0xFF)
		return output
	if width == 32 and value <= 0xFFFFFFFF:
		output.append(0xF2)
		for shift in [0, 8, 16, 24]:
			output.append((value >> shift) & 0xFF)
		output.append(0xFF)
		return output
	return PackedByteArray()


func _byte_json_integer(value: Variant) -> bool:
	return ContractValues.nonnegative_json_integer(value) and int(value) <= 0xFF


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
