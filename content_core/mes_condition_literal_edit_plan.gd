class_name KakyuMesConditionLiteralEditPlan
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
	"kind", "source_offset", "instruction_raw_sha256", "literal_offset", "value",
]
const TARGET_KEYS := [
	"node_id", "region_id", "op", "command_id", "instruction_start",
	"instruction_end", "instruction_raw_hex", "instruction_raw_sha256",
	"condition_start", "condition_end", "condition_raw_hex",
	"condition_raw_sha256", "literal_start", "literal_end", "literal_raw_hex",
	"literal_raw_sha256", "value", "width", "terminator_offset", "terminator",
	"false_target",
]
const FALSE_TARGET_KEYS := [
	"reference_id", "operand_start", "operand_end", "operand_raw_hex",
	"operand_raw_sha256", "value", "in_code", "aligned", "target_region",
]
const REPLACEMENT_KEYS := [
	"value", "width", "literal_raw_hex", "literal_raw_sha256",
	"condition_raw_hex", "condition_raw_sha256", "instruction_raw_hex",
	"instruction_raw_sha256",
]
const SOURCE_IDENTITY_KEYS := ["archive", "entry", "source_kind", "archive_sha256"]
const COMPATIBILITY := {
	"policy": "planning_only_same_width_condition_literal_replacement",
	"input_editable_schema": "kakyu_mes_editable_ir/v1",
	"input_decompiler_schema": "kakyu_mes_decompiler_ir/v1",
	"supported_operation": "replace_condition_literal",
	"supported_instruction": {"op": "branch_if_not_true", "command_id": 11.0},
	"supported_literal_widths": [8.0, 16.0, 32.0],
	"u8_literal_policy": "unambiguous_token_00_through_7f_only",
	"selection_policy": "one_exact_ast_literal_source_offset",
	"length_policy": "replacement_literal_must_match_source_length",
	"binary_publication": "forbidden",
	"native_engine_compatibility": "unverified",
	"unknown_plan_schema": "reject",
	"unknown_v1_field": "reject",
}
const INVARIANTS := {
	"source_editable_ir_validated": true,
	"target_node_unique_and_typed": true,
	"source_instruction_hash_matched": true,
	"source_literal_unique_in_condition_ast": true,
	"replacement_literal_same_width_and_length": true,
	"condition_terminator_unchanged": true,
	"false_target_reference_bound": true,
	"false_target_operand_unchanged": true,
	"all_other_instruction_bytes_unchanged": true,
	"opaque_bytes_not_rewritten": true,
	"binary_not_published": true,
}


func validate(document: Dictionary) -> Dictionary:
	if (
		document.get("ok") != true
		or str(document.get("schema", ""))
		!= ContentCoreVersionScript.MES_CONDITION_LITERAL_EDIT_PLAN_SCHEMA
		or not ContractValues.has_exact_keys(document, PLAN_KEYS)
	):
		return _error("MES condition literal edit plan schema or fields changed.")
	if document.get("producer") != {
		"implementation": "python_phase6_condition_literal_edit_planner",
		"contract": ContentCoreVersionScript.MES_CONDITION_LITERAL_EDIT_PLAN_SCHEMA,
	}:
		return _error("MES condition literal edit plan producer changed.")
	if document.get("compatibility") != COMPATIBILITY:
		return _error("MES condition literal edit compatibility changed.")
	var retained_hash := str(document.get("payload_sha256", ""))
	if not ContractValues.is_sha256(retained_hash) or FingerprintScript.new().fingerprint(document) != retained_hash:
		return _error("MES condition literal edit plan fingerprint changed.")
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
		return _error("MES condition literal edit source identity changed.")
	var inputs = document.get("inputs")
	if (
		not inputs is Dictionary
		or not ContractValues.has_exact_keys(inputs, ["editable_ir_sha256", "decompiler_ir_sha256"])
		or not ContractValues.all_hash_values(inputs)
	):
		return _error("MES condition literal edit input identity changed.")
	var operation = document.get("operation")
	if not operation is Dictionary or not ContractValues.has_exact_keys(operation, OPERATION_KEYS):
		return _error("MES condition literal edit operation fields changed.")
	if (
		str(operation.get("kind", "")) != "replace_condition_literal"
		or not ContractValues.nonnegative_json_integer(operation.get("source_offset", -1))
		or not ContractValues.is_sha256(str(operation.get("instruction_raw_sha256", "")))
		or not ContractValues.nonnegative_json_integer(operation.get("literal_offset", -1))
		or not ContractValues.nonnegative_json_integer(operation.get("value", -1))
	):
		return _error("MES condition literal edit operation changed.")
	var target = document.get("target")
	var replacement = document.get("replacement")
	if not target is Dictionary or not ContractValues.has_exact_keys(target, TARGET_KEYS):
		return _error("MES condition literal edit target fields changed.")
	if not replacement is Dictionary or not ContractValues.has_exact_keys(replacement, REPLACEMENT_KEYS):
		return _error("MES condition literal edit replacement fields changed.")
	if (
		str(target.get("node_id", "")).is_empty()
		or str(target.get("region_id", "")).is_empty()
		or str(target.get("op", "")) != "branch_if_not_true"
		or not ContractValues.nonnegative_json_integer(target.get("command_id", -1))
		or int(target.command_id) != 0x0B
		or str(target.get("instruction_raw_sha256", ""))
		!= str(operation.instruction_raw_sha256)
		or not ContractValues.json_integer(target.get("literal_start", -1))
		or int(target.literal_start) != int(operation.literal_offset)
		or not ContractValues.json_integer(replacement.get("value", -1))
		or int(replacement.value) != int(operation.value)
	):
		return _error("MES condition literal edit typed target identity changed.")
	var byte_validation := _validate_bytes(target, replacement)
	if not byte_validation.ok:
		return byte_validation
	if document.get("assembly_ready") != true:
		return _error("MES condition literal edit plan is not assembly ready.")
	if document.get("invariants") != INVARIANTS:
		return _error("MES condition literal edit invariants changed.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CONDITION_LITERAL_EDIT_PLAN_SCHEMA,
		"payload_sha256": retained_hash,
		"source_identity": source_identity.duplicate(true),
		"instruction_start": int(target.instruction_start),
		"literal_start": int(target.literal_start),
		"width": int(target.width),
		"source_value": int(target.value),
		"replacement_value": int(replacement.value),
		"false_target": int(target.false_target.value),
		"mes_bytes": false,
	}


func _validate_bytes(target: Dictionary, replacement: Dictionary) -> Dictionary:
	for key in [
		"command_id", "instruction_start", "instruction_end", "condition_start",
		"condition_end", "literal_start", "literal_end", "value", "width",
		"terminator_offset", "terminator",
	]:
		if not ContractValues.nonnegative_json_integer(target.get(key, -1)):
			return _error("MES condition literal edit target coordinate changed.")
	if (
		not ContractValues.nonnegative_json_integer(replacement.get("value", -1))
		or not ContractValues.nonnegative_json_integer(replacement.get("width", -1))
	):
		return _error("MES condition literal edit replacement value changed.")
	var false_target = target.get("false_target")
	if not false_target is Dictionary or not ContractValues.has_exact_keys(false_target, FALSE_TARGET_KEYS):
		return _error("MES condition literal edit false-target fields changed.")
	for key in ["operand_start", "operand_end", "value"]:
		if not ContractValues.nonnegative_json_integer(false_target.get(key, -1)):
			return _error("MES condition literal edit false-target coordinate changed.")
	if (
		str(false_target.get("reference_id", "")).is_empty()
		or typeof(false_target.get("in_code")) != TYPE_BOOL
		or typeof(false_target.get("aligned")) != TYPE_BOOL
		or typeof(false_target.get("target_region")) != TYPE_STRING
	):
		return _error("MES condition literal edit false-target identity changed.")
	var instruction_start := int(target.instruction_start)
	var instruction_end := int(target.instruction_end)
	var condition_start := int(target.condition_start)
	var condition_end := int(target.condition_end)
	var literal_start := int(target.literal_start)
	var literal_end := int(target.literal_end)
	var operand_start := int(false_target.operand_start)
	var operand_end := int(false_target.operand_end)
	if (
		instruction_end <= instruction_start
		or condition_start != instruction_start + 1
		or literal_start < condition_start
		or literal_end > condition_end - 1
		or int(target.terminator_offset) != condition_end - 1
		or int(target.terminator) != 0xFF
		or operand_start != condition_end
		or operand_end != instruction_end
		or int(target.width) != int(replacement.width)
	):
		return _error("MES condition literal edit target boundary changed.")
	var source_instruction := ContractValues.decode_hex(str(target.instruction_raw_hex))
	var source_condition := ContractValues.decode_hex(str(target.condition_raw_hex))
	var source_literal := ContractValues.decode_hex(str(target.literal_raw_hex))
	var target_raw := ContractValues.decode_hex(str(false_target.operand_raw_hex))
	var output_instruction := ContractValues.decode_hex(str(replacement.instruction_raw_hex))
	var output_condition := ContractValues.decode_hex(str(replacement.condition_raw_hex))
	var output_literal := ContractValues.decode_hex(str(replacement.literal_raw_hex))
	if (
		source_instruction.is_empty()
		or source_condition.is_empty()
		or source_literal.is_empty()
		or target_raw.size() != 4
		or output_instruction.is_empty()
		or output_condition.is_empty()
		or output_literal.is_empty()
		or source_instruction.size() != output_instruction.size()
		or source_condition.size() != output_condition.size()
		or source_literal.size() != output_literal.size()
		or instruction_end - instruction_start != source_instruction.size()
		or condition_end - condition_start != source_condition.size()
		or literal_end - literal_start != source_literal.size()
		or int(source_instruction[0]) != 0x0B
	):
		return _error("MES condition literal edit planned length changed.")
	if (
		ContractValues.sha256_lenient(source_instruction) != str(target.instruction_raw_sha256)
		or ContractValues.sha256_lenient(source_condition) != str(target.condition_raw_sha256)
		or ContractValues.sha256_lenient(source_literal) != str(target.literal_raw_sha256)
		or ContractValues.sha256_lenient(target_raw) != str(false_target.operand_raw_sha256)
		or ContractValues.sha256_lenient(output_instruction) != str(replacement.instruction_raw_sha256)
		or ContractValues.sha256_lenient(output_condition) != str(replacement.condition_raw_sha256)
		or ContractValues.sha256_lenient(output_literal) != str(replacement.literal_raw_sha256)
	):
		return _error("MES condition literal edit planned hash changed.")
	if _read_u32(target_raw) != int(false_target.value):
		return _error("MES condition literal edit false-target value changed.")
	var expected_source_literal := _encode_literal_token(int(target.value), int(target.width))
	var expected_output_literal := _encode_literal_token(
		int(replacement.value), int(replacement.width)
	)
	if (
		expected_source_literal.is_empty()
		or expected_output_literal.is_empty()
		or source_literal != expected_source_literal
		or output_literal != expected_output_literal
	):
		return _error("MES condition literal edit literal encoding changed.")
	var condition_relative_start := condition_start - instruction_start
	var condition_relative_end := condition_end - instruction_start
	var literal_relative_start := literal_start - instruction_start
	var literal_relative_end := literal_end - instruction_start
	if (
		source_condition[source_condition.size() - 1] != 0xFF
		or source_instruction.slice(condition_relative_start, condition_relative_end)
		!= source_condition
		or source_instruction.slice(literal_relative_start, literal_relative_end)
		!= source_literal
		or source_instruction.slice(source_instruction.size() - 4) != target_raw
		or output_instruction.slice(output_instruction.size() - 4) != target_raw
	):
		return _error("MES condition literal edit source placement changed.")
	var expected_output := PackedByteArray()
	expected_output.append_array(source_instruction.slice(0, literal_relative_start))
	expected_output.append_array(output_literal)
	expected_output.append_array(source_instruction.slice(literal_relative_end))
	if (
		expected_output != output_instruction
		or output_instruction.slice(condition_relative_start, condition_relative_end)
		!= output_condition
	):
		return _error("MES condition literal edit replacement touched unrelated bytes.")
	return {"ok": true}


func _encode_literal_token(value: int, width: int) -> PackedByteArray:
	if value < 0:
		return PackedByteArray()
	if width == 8:
		return PackedByteArray([value]) if value <= 0x7F else PackedByteArray()
	var output := PackedByteArray()
	if width == 16 and value <= 0xFFFF:
		output.append(0xF1)
		output.append(value & 0xFF)
		output.append((value >> 8) & 0xFF)
		return output
	if width == 32 and value <= 0xFFFFFFFF:
		output.append(0xF2)
		for shift in [0, 8, 16, 24]:
			output.append((value >> shift) & 0xFF)
		return output
	return PackedByteArray()


func _read_u32(data: PackedByteArray) -> int:
	return (
		int(data[0])
		| (int(data[1]) << 8)
		| (int(data[2]) << 16)
		| (int(data[3]) << 24)
	)


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
