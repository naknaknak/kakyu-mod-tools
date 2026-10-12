class_name KakyuEventPlayerRules
extends RefCounted

## TD-11 unit 1: the Event Player's generic pure rules, moved out of
## `tools/content_suite/apps/event_player.gd` behaviour-neutrally. Static
## functions only, no instance state.

const MesSemanticDiffScript := preload("res://content_core/mes_semantic_diff.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")

const PROMISE_REJECTED_LOCATION_IDS_BY_OPTION := {
	1: [0, 1, 4, 8, 11, 13],
	2: [11, 13],
	3: [11, 13],
	4: [11, 13],
	5: [11, 13],
	6: [8, 11, 13],
	7: [8],
	8: [6, 7, 8, 9, 10, 11, 12, 13],
	9: [6, 7, 8, 9, 10, 11, 12, 13],
	10: [1, 6, 7, 8, 9, 10, 11, 12, 13],
}
const PROMISE_A_EVENING_GATE_OPTIONS := [8, 9, 10]


static func catalog_list_text(values: Array) -> String:
	return ", ".join(values) if not values.is_empty() else "not cataloged"


static func validate_run_interface(request: Dictionary, proof_path: String) -> Dictionary:
	var declared: Dictionary = request.interface
	if str(declared.kind) == "exact_original":
		if not proof_path.is_empty():
			return {"ok": false, "error": "Exact-original Run must not supply a semantic proof file."}
		return {"ok": true, "kind": "exact_original"}
	if proof_path.is_empty():
		return {"ok": false, "error": "Changed MES Run requires its complete Phase 6 semantic proof."}
	var proof_value = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
	if not proof_value is Dictionary:
		return {"ok": false, "error": "MES interface proof is not a JSON object."}
	var proof: Dictionary = proof_value
	var checked := MesSemanticDiffScript.new().validate(proof)
	var identity: Dictionary = proof.get("source_identity", {})
	var binding: Dictionary = proof.get("output_binding", {})
	if (
		not checked.get("ok", false)
		or str(proof.get("schema", "")) != str(declared.contract_schema)
		or str(proof.get("payload_sha256", "")) != str(declared.proof_sha256)
		or str(identity.get("archive", "")).to_lower() != str(request.content.archive)
		or str(identity.get("entry", "")).to_upper() != str(request.content.entry).to_upper()
		or str(identity.get("archive_sha256", "")) != str(request.content.source_archive_sha256)
		or str(binding.get("entry_sha256", "")) != str(request.content.effective_entry_sha256)
	):
		return {"ok": false, "error": "MES interface proof does not match the Run request."}
	return {"ok": true, "kind": "semantic_diff", "proof": proof}


static func run_request_analysis_start(launch: Dictionary, document: Dictionary) -> Dictionary:
	var value := int(launch.start_value)
	if str(launch.start_kind) == "address_entry":
		var entries: Array = document.get("entries", [])
		if value < 0 or value >= entries.size():
			return {"ok": false, "error": "MES Editor Run address-entry index is unavailable."}
		return {"ok": true, "offset": int(entries[value].offset), "entry_index": value}
	var bytecode: PackedByteArray = document.get("bytecode", PackedByteArray())
	var decoded := MesInstructionDecoderScript.new().decode_at(
		bytecode, value, int(document.get("header", {}).get("code_size", 0))
	)
	if not decoded.get("ok", false):
		return {"ok": false, "error": "MES Editor Run code offset is not a decodable instruction boundary."}
	return {"ok": true, "offset": value, "entry_index": -1}


static func project_run_preset(
	workspace_snapshot: Dictionary, event_id: String, preset_id: String
) -> Dictionary:
	var project: Dictionary = workspace_snapshot.get("project", {})
	var event_player: Dictionary = project.get("event_player", {})
	for value in event_player.get("presets", []):
		if (
			value is Dictionary and str(value.get("event_id", "")) == event_id
			and str(value.get("preset_id", "")) == preset_id
		):
			return (value as Dictionary).duplicate(true)
	return {}


static func matches_audited_startup_execution(document: Dictionary) -> bool:
	var code: PackedByteArray = document.get("bytecode", PackedByteArray())
	var code_size := int(document.get("header", {}).get("code_size", 0))
	var decoder := MesInstructionDecoderScript.new()
	for expected in [
		{"offset": 0x014C, "end_offset": 0x0160, "selector": 2, "target": "LIBLARY.LIB"},
		{"offset": 0x0165, "end_offset": 0x017A, "selector": 3, "target": "DEF_MAIN.MES"},
	]:
		var instruction: Dictionary = decoder.decode_at(code, int(expected.offset), code_size)
		if (
			not instruction.get("ok", false)
			or str(instruction.get("op", "")) != "inline_script_execution"
			or int(instruction.get("end_offset", -1)) != int(expected.end_offset)
			or str(instruction.get("operands", [{}])[0].get("name", "")) != str(expected.target)
			or int(instruction.get("operands", [{}])[0].get("execution_selector", -1)) != int(expected.selector)
		):
			return false
	return true


static func source_row_is_meaningful(summary: Dictionary) -> bool:
	return (
		bool(summary.get("meaningful", false))
		or int(summary.get("message_count", 0)) > 0
		or int(summary.get("definition_count", 0)) > 0
		or str(summary.get("status", "")) == "native_presentation_boundary"
	)


static func same_kind_source_table_neighbor(
	item: TreeItem,
	direction: int,
	selected_kind: String
) -> TreeItem:
	var candidate := item.get_prev() if direction < 0 else item.get_next()
	while candidate != null:
		if str(candidate.get_metadata(1)) == selected_kind:
			return candidate
		candidate = candidate.get_prev() if direction < 0 else candidate.get_next()
	return null


static func promise_option_route_state(option: int, entry_name: String, location_id: int, a_latch: int) -> String:
	var rejected_locations: Array = PROMISE_REJECTED_LOCATION_IDS_BY_OPTION.get(option, [])
	if location_id in rejected_locations:
		return "rejected"
	if entry_name.to_upper() == "A_PROMIS.MES" and option in PROMISE_A_EVENING_GATE_OPTIONS and a_latch == 0:
		return "entry_gate"
	return "allowed"


static func eventd01_background_specification(hhmm: int) -> Dictionary:
	if hhmm < 600:
		return {"hhmm": hhmm, "resource": "D01Z.MMO", "source_offset": 0x01AF}
	if hhmm < 900:
		return {"hhmm": hhmm, "resource": "D01X.MMO", "source_offset": 0x01CE}
	if hhmm < 1600:
		return {"hhmm": hhmm, "resource": "D01X.MMO", "source_offset": 0x01ED}
	if hhmm < 1800:
		return {"hhmm": hhmm, "resource": "D01Y.MMO", "source_offset": 0x020C}
	return {"hhmm": hhmm, "resource": "D01Z.MMO", "source_offset": 0x021F}


static func eventd05_background_specification(hhmm: int) -> Dictionary:
	if hhmm < 600:
		return {"hhmm": hhmm, "resource": "D05Z.MMO", "source_offset": 0x01BD}
	if hhmm < 900:
		return {"hhmm": hhmm, "resource": "D05X.MMO", "source_offset": 0x01DC}
	if hhmm < 1600:
		return {"hhmm": hhmm, "resource": "D05X.MMO", "source_offset": 0x01FB}
	if hhmm < 1800:
		return {"hhmm": hhmm, "resource": "D05Y.MMO", "source_offset": 0x021A}
	return {"hhmm": hhmm, "resource": "D05Z.MMO", "source_offset": 0x022D}


static func nested_trace_at(trace: Array, entry_name: String, offset: int) -> Dictionary:
	for untyped_record in trace:
		var record: Dictionary = untyped_record
		if str(record.get("source_entry", "")) == entry_name and int(record.get("source_offset", -1)) == offset:
			return record
	return {}


static func matches_audited_routine40_script_envelope(flow: Dictionary) -> bool:
	var rows := {}
	for untyped_row in flow.get("instructions", []):
		var row: Dictionary = untyped_row
		rows[int(row.get("source_offset", -1))] = row
	for required_offset in [
		0x1C8E, 0x1CA0, 0x1CA6, 0x1CB0, 0x1CBA, 0x1CD0, 0x1CD5,
		0x1CE1, 0x1CE8, 0x1CED, 0x1CF7, 0x1CFD, 0x1D02, 0x1D07, 0x1D0C,
	]:
		if not rows.has(required_offset):
			return false
	if (
		not matches_branch_row(rows[0x1C8E], "literal", -1, "", 1, 0x1D07)
		or not matches_write_row(rows[0x1CA0], 21, "state_ref", 18, 0)
		or not matches_branch_row(rows[0x1CA6], "binary", 21, "equal", 0, 0x1CBA)
		or int(rows[0x1CB0].get("continuation_target", -1)) != 0x1C8E
		or not matches_branch_row(rows[0x1CBA], "binary", 21, "less_than", 17, 0x1CD5)
		or int(rows[0x1CD0].get("continuation_target", -1)) != 0x1CED
		or not matches_branch_row(rows[0x1CD5], "binary", 21, "equal", 0xFFFF, 0x1CED)
		or not matches_write_row(rows[0x1CE1], 13, "literal", -1, 0xFFFF)
		or int(rows[0x1CE8].get("continuation_target", -1)) != 0x1D07
		or not matches_branch_row(rows[0x1CED], "binary", 18, "not_equal", 0, 0x1D02)
		or not matches_write_row(rows[0x1CF7], 13, "state_ref", 18, 0)
		or int(rows[0x1CFD].get("continuation_target", -1)) != 0x1D07
		or int(rows[0x1D02].get("continuation_target", -1)) != 0x1C8E
		or int(rows[0x1D07].get("routine_id", -1)) != 20
		or int(rows[0x1D0C].get("entry_index", -1)) != 0
	):
		return false
	for selector in range(1, 18):
		var offset := 0x1D11 + (selector - 1) * 5
		if not rows.has(offset) or int(rows[offset].get("record_value", -1)) != selector:
			return false
	return true


static func matches_audited_routine40_native_spans(spans: Array) -> bool:
	var expected := [
		{"source": 0x1C95, "payload": 0x1C96, "end": 0x1CA0, "command": 0x12, "payload_bytes": 10, "records": 3},
		{"source": 0x1CC4, "payload": 0x1CC5, "end": 0x1CD0, "command": 0x12, "payload_bytes": 11, "records": 3},
	]
	if spans.size() != expected.size():
		return false
	for index in range(expected.size()):
		var span: Dictionary = spans[index]
		var wanted: Dictionary = expected[index]
		if (
			int(span.get("source_offset", -1)) != int(wanted.source)
			or int(span.get("payload_start_offset", -1)) != int(wanted.payload)
			or int(span.get("payload_end_offset", -1)) != int(wanted.end)
			or int(span.get("end_offset", -1)) != int(wanted.end)
			or int(span.get("command_id", -1)) != int(wanted.command)
			or str(span.get("handler_family", "")) != "native_record_dispatch"
			or str(span.get("consumption_kind", "")) != "typed_record_list_until_zero"
			or int(span.get("payload_byte_count", -1)) != int(wanted.payload_bytes)
			or int(span.get("record_count", -1)) != int(wanted.records)
			or not bool(span.get("terminator_consumed", false))
			or str(span.get("dispatch_semantics", "")) != "unresolved_not_executed"
		):
			return false
	return true


static func matches_branch_row(row: Dictionary, ast_type: String, state_index: int, operation: String, value: int, target: int) -> bool:
	if int(row.get("command_id", -1)) != 0x0B or int(row.get("branch_target", -1)) != target:
		return false
	var ast: Dictionary = row.get("condition_ast", {})
	if str(ast.get("type", "")) != ast_type:
		return false
	if ast_type == "literal":
		return int(ast.get("value", -1)) == value
	return (
		str(ast.get("op", "")) == operation
		and is_state_u16_ref(ast.get("lhs", {}), state_index)
		and str(ast.get("rhs", {}).get("type", "")) == "literal"
		and int(ast.get("rhs", {}).get("value", -1)) == value
	)


static func matches_write_row(row: Dictionary, write_start: int, ast_type: String, state_index: int, value: int) -> bool:
	var expressions: Array = row.get("write_expressions", [])
	if (
		str(row.get("write_storage", "")) != "state_u16"
		or int(row.get("write_start", -1)) != write_start
		or int(row.get("write_count", 0)) != 1
		or expressions.size() != 1
	):
		return false
	var ast: Dictionary = expressions[0].get("ast", {})
	if str(ast.get("type", "")) != ast_type:
		return false
	return is_state_u16_ref(ast, state_index) if ast_type == "state_ref" else int(ast.get("value", -1)) == value


static func is_state_u16_ref(ast: Dictionary, index: int) -> bool:
	return (
		str(ast.get("type", "")) == "state_ref"
		and str(ast.get("storage", "")) == "state_u16"
		and str(ast.get("index", {}).get("type", "")) == "literal"
		and int(ast.get("index", {}).get("value", -1)) == index
	)


static func instruction_literal_record(instruction: Dictionary) -> int:
	if instruction.get("operands", []).is_empty():
		return -1
	var operand: Dictionary = instruction.operands[0]
	var records: Array = operand.get("records", [])
	if records.size() != 1 or str(records[0].get("type", "")) != "expression_record":
		return -1
	var expression: Dictionary = records[0].get("value", {})
	var ast: Dictionary = expression.get("ast", {})
	return int(ast.value) if expression.get("ok", false) and str(ast.get("type", "")) == "literal" else -1


static func parse_offset(value: String) -> Dictionary:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		return {"ok": false, "error": "Intro coordinate is empty."}
	var parsed: int
	if cleaned.to_lower().begins_with("0x"):
		var digits := cleaned.substr(2)
		if not digits.is_valid_hex_number():
			return {"ok": false, "error": "Intro coordinate is not valid hexadecimal."}
		parsed = digits.hex_to_int()
	else:
		if not cleaned.is_valid_int():
			return {"ok": false, "error": "Intro coordinate is not a valid integer."}
		parsed = cleaned.to_int()
	return {"ok": true, "value": parsed}


static func is_headless_display() -> bool:
	return DisplayServer.get_name() == "headless"
