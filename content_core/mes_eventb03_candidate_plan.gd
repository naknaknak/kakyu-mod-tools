class_name KakyuMesEventB03CandidatePlan
extends RefCounted

# Read-only, source-local inspection of the 01M station candidate arm. This
# does not prove which native or host path reaches the audited candidate guard.
const Version := preload("res://content_core/content_core_version.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const StateScript := preload("res://content_core/mes_sandbox_state.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SOURCE_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const SOURCE_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const GUARD_OFFSET := 0x7691
const GUARD_END := 0x76F1
const TRUE_PATH_END := 0x789F
const FALSE_BOUNDARY := 0x78A9
const ENTRY_69_END := 0x7940

const TRUE_START_DELTA := 0x0060
const HANDOFF_OFFSET_DELTA := 0x01FE
const HANDOFF_END_DELTA := 0x020E
const FALSE_BOUNDARY_DELTA := 0x0218
const ENTRY_END_DELTA := 0x02AF

const INPUT_KEYS := [
	"state_u16_7",
	"state_u16_19",
	"banked_u16_210",
	"global_u8_207",
	"global_u8_333",
	"global_u8_200",
	"global_u8_400",
	"global_u8_205",
	"global_u8_631",
	"state_u16_12",
	"global_u8_628",
]

const EXPECTED_ROWS := [
	[0x060, 0x065, "source_line_marker"],
	[0x065, 0x06A, "source_line_marker"],
	[0x06A, 0x072, "argument_slot_write_run"],
	[0x072, 0x077, "script_transfer"],
	[0x077, 0x07C, "source_line_marker"],
	[0x07C, 0x081, "source_line_marker"],
	[0x081, 0x086, "entry_label"],
	[0x086, 0x0C2, "text"],
	[0x0C2, 0x0C9, "system_call"],
	[0x0C9, 0x0CF, "argument_slot_write_run"],
	[0x0CF, 0x0D4, "script_transfer"],
	[0x0D4, 0x0D9, "source_line_marker"],
	[0x0D9, 0x0E6, "banked_u16_write_run"],
	[0x0E6, 0x0FB, "voice_marker"],
	[0x0FB, 0x108, "banked_u16_write_run"],
	[0x108, 0x10D, "source_line_marker"],
	[0x10D, 0x112, "entry_label"],
	[0x112, 0x13E, "text"],
	[0x13E, 0x145, "system_call"],
	[0x145, 0x14B, "argument_slot_write_run"],
	[0x14B, 0x150, "script_transfer"],
	[0x150, 0x155, "source_line_marker"],
	[0x155, 0x15A, "entry_label"],
	[0x15A, 0x18C, "text"],
	[0x18C, 0x193, "system_call"],
	[0x193, 0x199, "argument_slot_write_run"],
	[0x199, 0x19E, "script_transfer"],
	[0x19E, 0x1A3, "source_line_marker"],
	[0x1A3, 0x1A8, "entry_label"],
	[0x1A8, 0x1AC, "text"],
	[0x1AC, 0x1BD, "protagonist_name_insert"],
	[0x1BD, 0x1E7, "text"],
	[0x1E7, 0x1EE, "system_call"],
	[0x1EE, 0x1F4, "argument_slot_write_run"],
	[0x1F4, 0x1F9, "script_transfer"],
	[0x1F9, 0x1FE, "source_line_marker"],
	[0x1FE, 0x20E, "script_handoff_marker"],
]


func build(source_payload: PackedByteArray, input_value: Variant) -> Dictionary:
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var document := ContainerScript.new().parse(source_payload)
	if (
		not document.get("ok", false)
		or str(document.get("entry_sha256", "")) != SOURCE_SHA256
		or str(document.get("bytecode_sha256", "")) != SOURCE_BYTECODE_SHA256
	):
		return _error("EVENTB03 candidate planning requires the audited original 01M.MES payload.")
	if not _original_entry_layout_matches(document):
		return _error("EVENTB03 candidate address-table ownership changed.")
	var inspected := _inspect(document.bytecode, GUARD_OFFSET, ENTRY_69_END)
	if not inspected.get("ok", false):
		return inspected
	var evaluated := _evaluate(inspected.get("guard_ast", {}), normalized.values)
	if not evaluated.get("ok", false):
		return evaluated
	inspected.erase("guard_ast")
	var candidate := bool(evaluated.candidate)
	inspected["schema"] = Version.MES_EVENTB03_CANDIDATE_PLAN_SCHEMA
	inspected["producer"] = {
		"core_version": Version.CORE_VERSION,
		"instruction_schema": Version.MES_INSTRUCTION_SCHEMA,
	}
	inspected["source"] = {
		"archive": "mes.arc",
		"entry": "01M.MES",
		"entry_sha256": str(document.entry_sha256),
		"bytecode_sha256": str(document.bytecode_sha256),
		"offset_basis": "code_start",
		"guard_offset": GUARD_OFFSET,
		"guard_end_offset": GUARD_END,
		"candidate_true_offset": GUARD_END,
		"candidate_false_offset": FALSE_BOUNDARY,
		"handoff_offset": 0x788F,
		"handoff_end_offset": TRUE_PATH_END,
		"entry_69_end_offset": ENTRY_69_END,
	}
	inspected["input"] = normalized.values.duplicate(true)
	inspected["candidate"] = {
		"matched": candidate,
		"value": int(evaluated.value),
		"next_offset": GUARD_END if candidate else FALSE_BOUNDARY,
	}
	inspected["selected_boundary"] = (
		inspected.true_path.handoff.duplicate(true)
		if candidate
		else {
			"kind": "candidate_false_boundary",
			"offset": FALSE_BOUNDARY,
			"end_offset": FALSE_BOUNDARY,
		}
	)
	inspected["execution"] = {
		"kind": "read_only_projection",
		"state_mutation": false,
		"compatibility": "remake_only",
		"natural_scheduler_eligibility": "unqualified",
		"upstream_preemption": "unresolved",
		"native_cadence": "unresolved",
		"post_handoff_tool_execution": false,
	}
	return inspected


func validate(source_payload: PackedByteArray, plan: Dictionary) -> Dictionary:
	var normalized := _normalize_input(plan.get("input", null), true)
	if not normalized.get("ok", false):
		return _error("EVENTB03 candidate plan input is malformed.")
	var rebuilt := build(source_payload, normalized.values)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("EVENTB03 candidate plan no longer matches its source-bound projection.")
	return {"ok": true}


func _inspect(code: PackedByteArray, base_offset: int, entry_end: int) -> Dictionary:
	if (
		base_offset < 0
		or entry_end != base_offset + ENTRY_END_DELTA
		or entry_end > code.size()
	):
		return _error("EVENTB03 candidate inspection bounds changed.")
	var guard := _record(code, base_offset, base_offset + TRUE_START_DELTA, "branch_if_not_true")
	if guard.is_empty() or int(guard.end_offset) != base_offset + TRUE_START_DELTA:
		return _error("EVENTB03 candidate guard is not one exact structural record.")
	var guard_ast: Dictionary = guard.get("operands", [{}])[0].get("value", {}).get("ast", {})
	if _signature(guard_ast) != _expected_guard_signature():
		return _error("EVENTB03 candidate guard expression changed.")
	if int(guard.get("operands", [{}, {}])[1].get("value", -1)) != base_offset + FALSE_BOUNDARY_DELTA:
		return _error("EVENTB03 candidate false boundary changed.")

	var records := {}
	for row in EXPECTED_ROWS:
		var offset := base_offset + int(row[0])
		var expected_end := base_offset + int(row[1])
		var record := _record(code, offset, base_offset + HANDOFF_END_DELTA, str(row[2]))
		if record.is_empty() or int(record.end_offset) != expected_end:
			return _error("EVENTB03 candidate true path changed at 0x%X." % offset)
		records[offset] = record
	if not _source_lines_match(records, base_offset):
		return _error("EVENTB03 candidate source-line checkpoints changed.")
	if not _entry_labels_match(records, base_offset):
		return _error("EVENTB03 candidate address-entry labels changed.")
	if not _dialogue_trailers_match(records, code, base_offset):
		return _error("EVENTB03 candidate dialogue boundary changed.")
	if not _routine_checkpoints_match(records, base_offset):
		return _error("EVENTB03 candidate routine or message record changed.")
	if not _dynamic_name_checkpoint_matches(records, base_offset):
		return _error("EVENTB03 candidate protagonist-name record changed.")
	if not _voice_span_matches(records, base_offset):
		return _error("EVENTB03 candidate voice span changed.")
	var handoff: Dictionary = records[base_offset + HANDOFF_OFFSET_DELTA]
	if (
		str(handoff.get("script_target", "")).to_upper() != "EVENTB03.MES"
		or int(handoff.get("command_id", -1)) != 0x0E
	):
		return _error("EVENTB03 candidate script handoff changed.")

	return {
		"ok": true,
		"guard_ast": guard_ast.duplicate(true),
		"guard": {
			"offset": base_offset,
			"end_offset": base_offset + TRUE_START_DELTA,
			"false_offset": base_offset + FALSE_BOUNDARY_DELTA,
			"sha256": ContractValues.sha256(code.slice(base_offset, base_offset + TRUE_START_DELTA)),
			"unique_state_reference_count": INPUT_KEYS.size(),
			"predicate_signature": _expected_guard_signature().duplicate(true),
		},
		"true_path": {
			"offset": base_offset + TRUE_START_DELTA,
			"end_offset": base_offset + HANDOFF_END_DELTA,
			"sha256": ContractValues.sha256(code.slice(base_offset + TRUE_START_DELTA, base_offset + HANDOFF_END_DELTA)),
			"routine23_request": {
				"argument_offset": base_offset + 0x06A,
				"call_offset": base_offset + 0x072,
				"routine_id": 23,
				"selector": 133,
			},
			"dialogues": _sanitized_dialogue_checkpoints(base_offset),
			"voice": {
				"set_offset": base_offset + 0x0D9,
				"set_end_offset": base_offset + 0x0E6,
				"storage": "banked_u16",
				"bank": 0,
				"index": 2,
				"set_operation": "bit_or",
				"set_mask": 128,
				"marker_offset": base_offset + 0x0E6,
				"marker_end_offset": base_offset + 0x0FB,
				"entry": "B0001.OGG",
				"clear_offset": base_offset + 0x0FB,
				"clear_end_offset": base_offset + 0x108,
				"clear_operation": "bit_and",
				"clear_mask": 65407,
			},
			"handoff": {
				"kind": "script_handoff_boundary",
				"offset": base_offset + HANDOFF_OFFSET_DELTA,
				"end_offset": base_offset + HANDOFF_END_DELTA,
				"command": 0x0E,
				"target_entry": "EVENTB03.MES",
				"target_start_coordinate": "not_encoded",
				"caller_frame": "not_encoded",
				"sha256": ContractValues.sha256(code.slice(base_offset + HANDOFF_OFFSET_DELTA, base_offset + HANDOFF_END_DELTA)),
			},
		},
		"excluded_tail": {
			"kind": "excluded_after_script_handoff",
			"offset": base_offset + HANDOFF_END_DELTA,
			"end_offset": entry_end,
			"sha256": ContractValues.sha256(code.slice(base_offset + HANDOFF_END_DELTA, entry_end)),
			"tool_executed": false,
			"native_post_handoff": "unresolved",
		},
	}


func _evaluate(ast: Dictionary, input_value: Variant) -> Dictionary:
	if _signature(ast) != _expected_guard_signature():
		return _error("EVENTB03 candidate evaluation requires the exact source guard.")
	var normalized := _normalize_input(input_value, false)
	if not normalized.get("ok", false):
		return normalized
	var state := StateScript.new(1)
	for key in INPUT_KEYS:
		var binding: Dictionary = _input_binding(key)
		state.write_value(binding.storage, int(binding.index), int(normalized.values[key]), int(binding.bank))
	var before := state.snapshot()
	var evaluated := ExpressionScript.new().evaluate(ast, state)
	if (
		not evaluated.get("ok", false)
		or int(evaluated.get("value", -1)) not in [0, 1]
		or state.snapshot() != before
	):
		return _error("EVENTB03 candidate guard evaluation failed or changed state.")
	return {
		"ok": true,
		"value": int(evaluated.value),
		"candidate": int(evaluated.value) == 1,
	}


func _original_entry_layout_matches(document: Dictionary) -> bool:
	var entries: Array = document.get("entries", [])
	if entries.size() <= 69:
		return false
	for expected in [
		[65, 0x75DE, 0x7712],
		[66, 0x7712, 0x779E],
		[67, 0x779E, 0x77E6],
		[68, 0x77E6, 0x7834],
		[69, 0x7834, ENTRY_69_END],
	]:
		var entry: Dictionary = entries[int(expected[0])]
		if int(entry.get("index", -1)) != int(expected[0]) or int(entry.get("offset", -1)) != int(expected[1]) or int(entry.get("end_offset", -1)) != int(expected[2]):
			return false
	return true


func _source_lines_match(records: Dictionary, base: int) -> bool:
	for row in [
		[0x060, 1050], [0x065, 1051], [0x077, 1052], [0x07C, 1053],
		[0x0D4, 1055], [0x108, 1056], [0x150, 1058], [0x19E, 1060], [0x1F9, 1062],
	]:
		var record: Dictionary = records.get(base + int(row[0]), {})
		if record.get("operands", []).is_empty() or int(record.operands[0].get("value", -1)) != int(row[1]):
			return false
	return true


func _entry_labels_match(records: Dictionary, base: int) -> bool:
	for row in [[0x081, 66], [0x10D, 67], [0x155, 68], [0x1A3, 69]]:
		var record: Dictionary = records.get(base + int(row[0]), {})
		if record.get("operands", []).is_empty() or int(record.operands[0].get("value", -1)) != int(row[1]):
			return false
	return true


func _dialogue_trailers_match(records: Dictionary, code: PackedByteArray, base: int) -> bool:
	# Each page ends in the message wait System.function[19](2): one call,
	# 0D 13 FF 02 02 FF 00, that closes the dialogue boundary.
	for row in [
		[0x081, 0x0C2, 0x0C9],
		[0x10D, 0x13E, 0x145],
		[0x155, 0x18C, 0x193],
		[0x1A3, 0x1E7, 0x1EE],
	]:
		if not records.has(base + int(row[0])) or not records.has(base + int(row[1])):
			return false
		var wait: Dictionary = records[base + int(row[1])]
		if (
			str(wait.get("op", "")) != "system_call"
			or int(wait.get("system_function", -1)) != 19
			or int(wait.get("end_offset", -1)) != base + int(row[2])
		):
			return false
		if code.slice(base + int(row[1]), base + int(row[2])) != PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00]):
			return false
	return true


func _routine_checkpoints_match(records: Dictionary, base: int) -> bool:
	if not _argument_assignment(records.get(base + 0x06A, {}), 1, 133) or not _routine_call(records.get(base + 0x072, {}), 23):
		return false
	for row in [
		[0x0C9, 0x0CF, 66],
		[0x145, 0x14B, 67],
		[0x193, 0x199, 68],
		[0x1EE, 0x1F4, 69],
	]:
		if not _argument_assignment(records.get(base + int(row[0]), {}), 1, int(row[2])) or not _routine_call(records.get(base + int(row[1]), {}), 0):
			return false
	return true


func _dynamic_name_checkpoint_matches(records: Dictionary, base: int) -> bool:
	var record: Dictionary = records.get(base + 0x1AC, {})
	var record_list: Array = record.get("operands", [{}])[0].get("records", [])
	if record_list.size() != 1 or str(record_list[0].get("type", "")) != "expression_record":
		return false
	return _signature(record_list[0].get("value", {}).get("ast", {})) == [
		"add",
		["add", ["state_ref", "banked_i32", 0, 0], ["state_ref", "banked_u16", 0, 0]],
		2880,
	]


func _voice_span_matches(records: Dictionary, base: int) -> bool:
	if not _span_write(records.get(base + 0x0D9, {}), "bit_or", 128):
		return false
	if not _span_write(records.get(base + 0x0FB, {}), "bit_and", 65407):
		return false
	var voice: Dictionary = records.get(base + 0x0E6, {})
	var operands: Array = voice.get("operands", [])
	return (
		operands.size() == 1
		and str(operands[0].get("name", "")).to_upper() == "B0001.OGG"
		and int(operands[0].get("presentation_subcommand", -1)) == 7
		and int(operands[0].get("queue_selector", -1)) == 2
		and int(operands[0].get("playback_selector", -1)) == 3
	)


func _span_write(record: Dictionary, operation: String, mask: int) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 3 or _signature(operands[0].get("value", {}).get("ast", {})) != 2 or int(operands[1].get("value", -1)) != 0:
		return false
	var pairs: Array = operands[2].get("pairs", [])
	return pairs.size() == 1 and int(pairs[0].get("continuation", -1)) == 0 and _signature(pairs[0].get("expression", {}).get("ast", {})) == [operation, ["state_ref", "banked_u16", 0, 2], mask]


func _argument_assignment(record: Dictionary, slot: int, value: int) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 2 or int(operands[0].get("value", -1)) != slot:
		return false
	var pairs: Array = operands[1].get("pairs", [])
	return pairs.size() == 1 and int(pairs[0].get("continuation", -1)) == 0 and _signature(pairs[0].get("expression", {}).get("ast", {})) == value


func _routine_call(record: Dictionary, routine_id: int) -> bool:
	var records: Array = record.get("operands", [{}])[0].get("records", [])
	return records.size() == 1 and str(records[0].get("type", "")) == "expression_record" and _signature(records[0].get("value", {}).get("ast", {})) == routine_id


func _sanitized_dialogue_checkpoints(base: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in [
		[66, 0x081, 0x10D, 0x0C2, 0x0C2, 0x0C9, 0x0CF, 0x0D4, 1055, false],
		[67, 0x10D, 0x155, 0x13E, 0x13E, 0x145, 0x14B, 0x150, 1058, false],
		[68, 0x155, 0x1A3, 0x18C, 0x18C, 0x193, 0x199, 0x19E, 1060, false],
		[69, 0x1A3, 0x2AF, 0x1E7, 0x1E7, 0x1EE, 0x1F4, 0x1F9, 1062, true],
	]:
		result.append({
			"entry_index": int(row[0]),
			"label_offset": base + int(row[1]),
			"declared_end_offset": base + int(row[2]),
			"cursor_offset": base + int(row[3]),
			"trailer_offset": base + int(row[4]),
			"resume_offset": base + int(row[5]),
			"message_id": int(row[0]),
			"argument_offset": base + int(row[5]),
			"routine_offset": base + int(row[6]),
			"source_line_offset": base + int(row[7]),
			"source_line": int(row[8]),
			"protagonist_name_insert": bool(row[9]),
		})
	return result


func _expected_guard_signature() -> Variant:
	var conditions: Array = [
		["greater_than", ["state_ref", "state_u16", 0, 7], 400],
		["less_than", ["state_ref", "state_u16", 0, 7], 616],
		["greater_than", ["state_ref", "state_u16", 0, 19], 1800],
		["less_than", ["state_ref", "state_u16", 0, 19], 2001],
		["greater_than", ["state_ref", "banked_u16", 0, 210], 40],
		["less_than", ["state_ref", "banked_u16", 0, 210], 80],
		["not_equal", ["state_ref", "global_u8", 0, 207], 2],
		["equal", ["state_ref", "global_u8", 0, 333], 0],
		["equal", ["state_ref", "global_u8", 0, 200], 0],
		["equal", ["state_ref", "global_u8", 0, 400], 1],
		["equal", ["state_ref", "global_u8", 0, 205], 0],
		["equal", ["state_ref", "global_u8", 0, 631], 0],
		["not_equal", ["state_ref", "state_u16", 0, 12], 0],
		["equal", ["state_ref", "global_u8", 0, 628], 0],
	]
	var result: Variant = conditions[0]
	for index in range(1, conditions.size()):
		result = ["logical_and", result, conditions[index]]
	return result


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 32:
		return null
	match str(ast.get("type", "")):
		"literal":
			return ast.get("value")
		"state_ref":
			return [
				"state_ref",
				str(ast.get("storage", "")),
				int(ast.get("bank", -1)),
				_signature(ast.get("index", {}), depth + 1),
			]
		"binary":
			return [str(ast.get("op", "")), _signature(ast.get("lhs", {}), depth + 1), _signature(ast.get("rhs", {}), depth + 1)]
	return null


func _normalize_input(input_value: Variant, json_compatible: bool) -> Dictionary:
	if not input_value is Dictionary or input_value.size() != INPUT_KEYS.size():
		return _error("EVENTB03 candidate input requires the exact source-state key set.")
	for untyped_key in input_value:
		if typeof(untyped_key) != TYPE_STRING or untyped_key not in INPUT_KEYS:
			return _error("EVENTB03 candidate input contains an unknown source-state key.")
	var result := {}
	for key in INPUT_KEYS:
		if not input_value.has(key):
			return _error("EVENTB03 candidate input is missing %s." % key)
		var value: Variant = input_value[key]
		if typeof(value) == TYPE_FLOAT and json_compatible:
			if not is_finite(float(value)) or float(value) != floor(float(value)):
				return _error("EVENTB03 candidate input values must be exact integers.")
			value = int(value)
		if typeof(value) != TYPE_INT:
			return _error("EVENTB03 candidate input values must be exact integers.")
		var maximum := 255 if key.begins_with("global_u8_") else 65535
		if int(value) < 0 or int(value) > maximum:
			return _error("EVENTB03 candidate input value is outside its source storage width.")
		result[key] = int(value)
	return {"ok": true, "values": result}


func _input_binding(key: String) -> Dictionary:
	match key:
		"state_u16_7": return {"storage": "state_u16", "bank": 0, "index": 7}
		"state_u16_19": return {"storage": "state_u16", "bank": 0, "index": 19}
		"banked_u16_210": return {"storage": "banked_u16", "bank": 0, "index": 210}
		"global_u8_207": return {"storage": "global_u8", "bank": 0, "index": 207}
		"global_u8_333": return {"storage": "global_u8", "bank": 0, "index": 333}
		"global_u8_200": return {"storage": "global_u8", "bank": 0, "index": 200}
		"global_u8_400": return {"storage": "global_u8", "bank": 0, "index": 400}
		"global_u8_205": return {"storage": "global_u8", "bank": 0, "index": 205}
		"global_u8_631": return {"storage": "global_u8", "bank": 0, "index": 631}
		"state_u16_12": return {"storage": "state_u16", "bank": 0, "index": 12}
		"global_u8_628": return {"storage": "global_u8", "bank": 0, "index": 628}
	return {}


func _record(code: PackedByteArray, offset: int, end: int, operation: String) -> Dictionary:
	if offset < 0 or offset >= end:
		return {}
	var record := DecoderScript.new().decode_at_structural(code, offset, end)
	if not record.get("ok", false) or str(record.get("op", "")) != operation or int(record.get("end_offset", end + 1)) > end:
		return {}
	return record


func _same_plan_value(actual: Variant, expected: Variant, depth := 0) -> bool:
	if depth > 32:
		return false
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key in actual:
			if typeof(key) != TYPE_STRING or not expected.has(key) or not _same_plan_value(actual[key], expected[key], depth + 1):
				return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_plan_value(actual[index], expected[index], depth + 1):
				return false
		return true
	if typeof(expected) == TYPE_INT:
		if typeof(actual) == TYPE_FLOAT:
			return is_finite(float(actual)) and float(actual) == floor(float(actual)) and float(actual) == float(expected)
		return typeof(actual) == TYPE_INT and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
