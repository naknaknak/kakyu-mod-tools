class_name KakyuMesStationCandidatePrefixPlan
extends RefCounted

# Read-only structural projection of the source prefix that precedes the
# station candidate cascade. It records local control flow and symbolic writes
# only; no MES instruction, registered definition, shared routine, native
# record, or presentation operation is executed by this class.
const ContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const SOURCE_SHA256 := "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5"
const SOURCE_BYTECODE_SHA256 := "f590b3007ea98dcce6f10bc85eb316abdf250f6417a87cec4ab0a6d98ed2230b"
const PREFIX_SHA256 := "4a669e767c925e7a988c0b7c169be9a250095a3091d4d20bb1d4e7b0cde24289"
const PREFIX_OFFSET := 0x0008
const PREFIX_END := 0x026D
const ENTRY_ZERO_END := 0x03AF
const RECORD_COUNT := 103


func build(source_payload: PackedByteArray) -> Dictionary:
	var document := ContainerScript.new().parse(source_payload)
	if (
		not document.get("ok", false)
		or str(document.get("entry_sha256", "")) != SOURCE_SHA256
		or str(document.get("bytecode_sha256", "")) != SOURCE_BYTECODE_SHA256
	):
		return _error("Station candidate prefix planning requires the audited original 01M.MES payload.")
	if not _entry_layout_matches(document):
		return _error("Station candidate prefix address-table ownership changed.")
	var code: PackedByteArray = document.bytecode
	if ContractValues.sha256(code.slice(PREFIX_OFFSET, PREFIX_END)) != PREFIX_SHA256:
		return _error("Station candidate prefix source slice changed.")
	var inspected := _inspect(code)
	if not inspected.get("ok", false):
		return inspected
	return _compose_plan(inspected.records, {
		"archive": "mes.arc",
		"entry": "01M.MES",
		"entry_sha256": SOURCE_SHA256,
		"bytecode_sha256": SOURCE_BYTECODE_SHA256,
		"offset_basis": "code_start",
		"address_entry_index": 0,
		"address_entry_offset": PREFIX_OFFSET,
		"address_entry_end_offset": ENTRY_ZERO_END,
		"prefix_offset": PREFIX_OFFSET,
		"prefix_end_offset": PREFIX_END,
		"prefix_sha256": PREFIX_SHA256,
	})


func validate(source_payload: PackedByteArray, plan: Dictionary) -> Dictionary:
	var rebuilt := build(source_payload)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Station candidate prefix plan no longer matches its source-bound projection.")
	return {"ok": true}


# Test-only composition boundary. Synthetic tests provide normalized record
# descriptors rather than embedding the original 613-byte source prefix.
func _build_from_partition_for_test(partition: Variant) -> Dictionary:
	var normalized := _normalize_partition(partition)
	if not normalized.get("ok", false):
		return normalized
	return _compose_plan(normalized.records, {
		"archive": "synthetic_fixture",
		"entry": "01M.MES-shaped-prefix",
		"entry_sha256": "not_applicable",
		"bytecode_sha256": "not_applicable",
		"offset_basis": "code_start",
		"address_entry_index": 0,
		"address_entry_offset": PREFIX_OFFSET,
		"address_entry_end_offset": ENTRY_ZERO_END,
		"prefix_offset": PREFIX_OFFSET,
		"prefix_end_offset": PREFIX_END,
		"prefix_sha256": _partition_fingerprint(normalized.records),
	})


func _validate_from_partition_for_test(partition: Variant, plan: Dictionary) -> Dictionary:
	var rebuilt := _build_from_partition_for_test(partition)
	if not rebuilt.get("ok", false):
		return rebuilt
	if not _same_plan_value(plan, rebuilt):
		return _error("Synthetic station candidate prefix plan changed.")
	return {"ok": true}


func _inspect(code: PackedByteArray) -> Dictionary:
	if code.size() < PREFIX_END:
		return _error("Station candidate prefix is truncated.")
	var decoder := DecoderScript.new()
	var records: Array[Dictionary] = []
	var decoded := {}
	for order in range(_expected_rows().size()):
		var expected: Dictionary = _expected_rows()[order]
		var offset := int(expected.offset)
		var end_offset := int(expected.end_offset)
		var record: Dictionary = decoder.decode_at_structural(code, offset, end_offset)
		if (
			not record.get("ok", false)
			or str(record.get("op", "")) != str(expected.op)
			or int(record.get("end_offset", -1)) != end_offset
		):
			return _error("Station candidate prefix record %d boundary changed." % order)
		records.append({
			"order": order,
			"offset": offset,
			"end_offset": end_offset,
			"op": str(expected.op),
			"sha256": ContractValues.sha256(code.slice(offset, end_offset)),
		})
		decoded[offset] = record
	if records.size() != RECORD_COUNT or int(records[0].offset) != PREFIX_OFFSET or int(records[-1].end_offset) != PREFIX_END:
		return _error("Station candidate prefix partition changed.")
	if not _semantics_match(decoded):
		return _error("Station candidate prefix typed semantics changed.")
	return {"ok": true, "records": records}


func _compose_plan(records: Array, source: Dictionary) -> Dictionary:
	var by_offset := {}
	for untyped_record in records:
		var record: Dictionary = untyped_record
		by_offset[int(record.offset)] = record
	return {
		"ok": true,
		"schema": Version.MES_STATION_CANDIDATE_PREFIX_PLAN_SCHEMA,
		"producer": {
			"core_version": Version.CORE_VERSION,
			"instruction_schema": Version.MES_INSTRUCTION_SCHEMA,
		},
		"source": source.duplicate(true),
		"record_partition": {
			"offset": PREFIX_OFFSET,
			"end_offset": PREFIX_END,
			"record_count": RECORD_COUNT,
			"typed_record_count": RECORD_COUNT,
			"opaque_record_count": 0,
			"records": records.duplicate(true),
		},
		"local_flow": _local_flow(by_offset),
		"symbolic_effects": _symbolic_effects(),
		"external_boundaries": _external_boundaries(by_offset),
		"execution": {
			"kind": "read_only_symbolic_projection",
			"mes_instruction_execution": false,
			"local_effect_application": false,
			"external_call_execution": false,
			"native_effect_execution": false,
			"state_mutation": false,
			"post_prefix_state": "not_computed",
			"external_completion": "unresolved",
			"prefix_join_reachability": "conditional",
			"entry_zero_reachability": "unqualified",
			"host_zero_start": "unresolved",
			"native_address_row_selection": "unresolved",
			"natural_scheduler_eligibility": "unqualified",
			"native_cadence": "unresolved",
		},
	}


func _local_flow(records: Dictionary) -> Dictionary:
	return {
		"kind": "symbolic_local_cfg",
		"entry_offset": PREFIX_OFFSET,
		"loop": {
			"counter": {"storage": "state_u16", "index": 2},
			"initialization": {"offset": 0x0169, "end_offset": 0x016E, "value": 0, "sha256": _record_hash(records, 0x0169)},
			"guard": {
				"offset": 0x016E, "end_offset": 0x0178,
				"predicate_signature": ["less_than", _state_ref("state_u16", 2), 16],
				"true_offset": 0x0178, "false_offset": 0x0196,
				"sha256": _record_hash(records, 0x016E),
			},
			"body": {
				"copy_offset": 0x0178, "copy_end_offset": 0x0189,
				"destination_signature": ["add", 31, _state_ref("state_u16", 2)],
				"source_signature": _state_ref("banked_u16", ["add", 168, _state_ref("state_u16", 2)]),
				"copy_sha256": _record_hash(records, 0x0178),
				"increment_offset": 0x0189, "increment_end_offset": 0x0191,
				"increment_signature": ["add", _state_ref("state_u16", 2), 1],
				"increment_sha256": _record_hash(records, 0x0189),
			},
			"back_edge": {"offset": 0x0191, "end_offset": 0x0196, "target_offset": 0x016E, "sha256": _record_hash(records, 0x0191)},
			"local_iteration_count": 16,
			"exit_offset": 0x0196,
		},
		"surface_branch": {
			"guard": {
				"offset": 0x01EF, "end_offset": 0x01FA,
				"predicate_signature": ["equal", _state_ref("global_u8", 2847), 1],
				"true_offset": 0x01FA, "false_offset": 0x0224,
				"sha256": _record_hash(records, 0x01EF),
			},
			"true_path": {
				"surface_offset": 0x01FA, "surface_end_offset": 0x021F,
				"continuation_offset": 0x021F, "continuation_end_offset": 0x0224,
				"continuation_target": 0x0229,
			},
			"false_path": {
				"shared_routine_offset": 0x0224, "shared_routine_end_offset": 0x0229,
				"routine_id": 21, "physical_resume": 0x0229,
			},
			"join_offset": 0x0229,
		},
		"conditional_join": {
			"kind": "candidate_cascade_prefix_join",
			"offset": PREFIX_END,
			"end_offset": PREFIX_END,
			"requires_external_completion": true,
			"reached_by_tool": false,
			"next_plan_schema": Version.MES_STATION_CANDIDATE_PRIORITY_PLAN_SCHEMA,
			"delegated": false,
		},
	}


func _symbolic_effects() -> Array[Dictionary]:
	return [
		{"kind": "manager_vector_clear", "offset": 0x000D, "end_offset": 0x0062, "selectors": range(1, 18), "mapped_gameplay_state": false},
		{"kind": "literal_write_range", "offset": 0x00D0, "end_offset": 0x0112, "storage": "global_u8", "start_index": 10, "count": 11, "value": 0},
		{"kind": "expression_write", "offset": 0x0117, "end_offset": 0x011E, "storage": "global_u8", "index": 350, "value_signature": ["call", "random_below", [3]], "evaluated": false},
		{"kind": "expression_write", "offset": 0x0123, "end_offset": 0x012A, "storage": "global_u8", "index": 351, "value_signature": ["call", "random_below", [13]], "evaluated": false},
		{"kind": "literal_write", "offset": 0x013E, "end_offset": 0x0143, "storage": "state_u16", "index": 2, "value": 15},
		{"kind": "literal_write", "offset": 0x014D, "end_offset": 0x0152, "storage": "state_u16", "index": 2, "value": 1},
		{"kind": "literal_write", "offset": 0x0163, "end_offset": 0x0169, "storage": "global_u8", "index": 3005, "value": 15},
		{"kind": "bounded_copy_loop", "offset": 0x0169, "end_offset": 0x0196, "source_storage": "banked_u16", "source_bank": 0, "source_start": 168, "destination_storage": "banked_u16", "destination_bank": 0, "destination_start": 31, "count": 16, "counter_storage": "state_u16", "counter_index": 2, "counter_final": 16},
		{"kind": "literal_write", "offset": 0x0196, "end_offset": 0x019C, "storage": "global_u8", "index": 3000, "value": 0},
		{"kind": "literal_write", "offset": 0x01D1, "end_offset": 0x01D8, "storage": "banked_u16", "bank": 0, "index": 1, "value": 1},
		{"kind": "literal_write", "offset": 0x01D8, "end_offset": 0x01DE, "storage": "argument_slot", "index": 1, "value": 11},
		{"kind": "literal_write", "offset": 0x01E3, "end_offset": 0x01EA, "storage": "banked_u16", "bank": 0, "index": 1, "value": 7},
		{"kind": "literal_write", "offset": 0x0229, "end_offset": 0x022F, "storage": "global_u8", "index": 2836, "value": 0},
		{"kind": "literal_write", "offset": 0x022F, "end_offset": 0x0235, "storage": "global_u8", "index": 3000, "value": 0},
		{"kind": "literal_write", "offset": 0x0235, "end_offset": 0x023B, "storage": "global_u8", "index": 2841, "value": 0},
	]


func _external_boundaries(records: Dictionary) -> Array[Dictionary]:
	var rows := [
		["registered_definition", 0x0143, 0x0148, 11, "always"],
		["shared_routine", 0x0152, 0x0157, 32, "always"],
		["ax_presentation_control", 0x015C, 0x0163, 7, "always"],
		["shared_routine", 0x019C, 0x01A1, 25, "always"],
		["native_record_dispatch", 0x01A1, 0x01A9, 0, "always"],
		["native_record_dispatch", 0x01A9, 0x01B1, 0, "always"],
		["native_record_dispatch", 0x01B1, 0x01B9, 0, "always"],
		["ax_presentation_control", 0x01C3, 0x01CA, 6, "always"],
		["ax_presentation_control", 0x01CA, 0x01D1, 8, "always"],
		["shared_routine", 0x01DE, 0x01E3, 27, "always"],
		["shared_routine", 0x01EA, 0x01EF, 25, "always"],
		["surface_operation", 0x01FA, 0x021F, 11, "global_u8[2847] == 1"],
		["shared_routine", 0x0224, 0x0229, 21, "global_u8[2847] != 1"],
	]
	var result: Array[Dictionary] = []
	for order in range(rows.size()):
		var row: Array = rows[order]
		var item := {
			"order": order,
			"kind": str(row[0]),
			"offset": int(row[1]),
			"end_offset": int(row[2]),
			"physical_resume": int(row[2]),
			"condition": str(row[4]),
			"sha256": _record_hash(records, int(row[1])),
			"tool_execution": false,
			"completion": "unresolved",
		}
		match str(row[0]):
			"registered_definition": item["selector"] = int(row[3])
			"shared_routine": item["routine_id"] = int(row[3])
			"ax_presentation_control":
				item["presentation_subcommand"] = 3
				item["execution_selector"] = int(row[3])
			"native_record_dispatch": item["record_values"] = _native_record_values(int(row[1]))
			"surface_operation": item["presentation_subcommand"] = int(row[3])
		result.append(item)
	return result


func _semantics_match(records: Dictionary) -> bool:
	if not _entry_label(records.get(0x0008, {}), 0):
		return false
	for selector in range(1, 18):
		if not _literal_record(records.get(0x000D + (selector - 1) * 5, {}), selector):
			return false
	for pair in _source_line_rows():
		if not _source_line(records.get(int(pair[0]), {}), int(pair[1])):
			return false
	for index in range(10, 21):
		if not _simple_write(records.get(0x00D0 + (index - 10) * 6, {}), index, 0):
			return false
	if not _simple_write(records.get(0x0117, {}), 350, ["call", "random_below", [3]]):
		return false
	if not _simple_write(records.get(0x0123, {}), 351, ["call", "random_below", [13]]):
		return false
	if not _simple_write(records.get(0x013E, {}), 2, 15):
		return false
	if not _literal_record(records.get(0x0143, {}), 11):
		return false
	if not _simple_write(records.get(0x014D, {}), 2, 1) or not _literal_record(records.get(0x0152, {}), 32):
		return false
	if not _ax_selector(records.get(0x015C, {}), 7):
		return false
	if not _simple_write(records.get(0x0163, {}), 3005, 15) or not _simple_write(records.get(0x0169, {}), 2, 0):
		return false
	if not _branch(records.get(0x016E, {}), ["less_than", _state_ref("state_u16", 2), 16], 0x0196):
		return false
	if not _loop_copy(records.get(0x0178, {})) or not _simple_write(records.get(0x0189, {}), 2, ["add", _state_ref("state_u16", 2), 1]):
		return false
	if not _continuation(records.get(0x0191, {}), 0x016E):
		return false
	if not _simple_write(records.get(0x0196, {}), 3000, 0) or not _literal_record(records.get(0x019C, {}), 25):
		return false
	for offset in [0x01A1, 0x01A9, 0x01B1]:
		if not _native_records(records.get(offset, {}), _native_record_values(offset)):
			return false
	if not _ax_selector(records.get(0x01C3, {}), 6) or not _ax_selector(records.get(0x01CA, {}), 8):
		return false
	if not _banked_write(records.get(0x01D1, {}), 1, 0, 1):
		return false
	if not _simple_write(records.get(0x01D8, {}), 1, 11) or not _literal_record(records.get(0x01DE, {}), 27):
		return false
	if not _banked_write(records.get(0x01E3, {}), 1, 0, 7) or not _literal_record(records.get(0x01EA, {}), 25):
		return false
	if not _branch(records.get(0x01EF, {}), ["equal", _state_ref("global_u8", 2847), 1], 0x0224):
		return false
	if not _surface_operation(records.get(0x01FA, {})) or not _continuation(records.get(0x021F, {}), 0x0229):
		return false
	if not _literal_record(records.get(0x0224, {}), 21):
		return false
	for row in [[0x0229, 2836], [0x022F, 3000], [0x0235, 2841]]:
		if not _simple_write(records.get(int(row[0]), {}), int(row[1]), 0):
			return false
	return true


func _expected_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"offset": 0x0008, "end_offset": 0x000D, "op": "entry_label"}]
	for index in range(17):
		rows.append({"offset": 0x000D + index * 5, "end_offset": 0x0012 + index * 5, "op": "command_1b"})
	for index in range(22):
		rows.append({"offset": 0x0062 + index * 5, "end_offset": 0x0067 + index * 5, "op": "source_line_marker"})
	for index in range(11):
		rows.append({"offset": 0x00D0 + index * 6, "end_offset": 0x00D6 + index * 6, "op": "global_u8_write_run"})
	for row in [
		[0x0112, 0x0117, "source_line_marker"], [0x0117, 0x011E, "global_u8_write_run"],
		[0x011E, 0x0123, "source_line_marker"], [0x0123, 0x012A, "global_u8_write_run"],
	]:
		rows.append({"offset": row[0], "end_offset": row[1], "op": row[2]})
	for index in range(4):
		rows.append({"offset": 0x012A + index * 5, "end_offset": 0x012F + index * 5, "op": "source_line_marker"})
	for row in [
		[0x013E, 0x0143, "state_u16_write_run"], [0x0143, 0x0148, "definition_invoke"],
		[0x0148, 0x014D, "source_line_marker"], [0x014D, 0x0152, "state_u16_write_run"],
		[0x0152, 0x0157, "script_transfer"], [0x0157, 0x015C, "source_line_marker"],
		[0x015C, 0x0163, "ax_presentation_control"], [0x0163, 0x0169, "global_u8_write_run"],
		[0x0169, 0x016E, "state_u16_write_run"], [0x016E, 0x0178, "branch_if_not_true"],
		[0x0178, 0x0189, "banked_u16_write_run"], [0x0189, 0x0191, "state_u16_write_run"],
		[0x0191, 0x0196, "continuation_transfer"], [0x0196, 0x019C, "global_u8_write_run"],
		[0x019C, 0x01A1, "script_transfer"], [0x01A1, 0x01A9, "native_record_dispatch"],
		[0x01A9, 0x01B1, "native_record_dispatch"], [0x01B1, 0x01B9, "native_record_dispatch"],
		[0x01B9, 0x01BE, "source_line_marker"], [0x01BE, 0x01C3, "source_line_marker"],
		[0x01C3, 0x01CA, "ax_presentation_control"], [0x01CA, 0x01D1, "ax_presentation_control"],
		[0x01D1, 0x01D8, "banked_u16_write_run"], [0x01D8, 0x01DE, "argument_slot_write_run"],
		[0x01DE, 0x01E3, "script_transfer"], [0x01E3, 0x01EA, "banked_u16_write_run"],
		[0x01EA, 0x01EF, "script_transfer"], [0x01EF, 0x01FA, "branch_if_not_true"],
		[0x01FA, 0x021F, "surface_operation"], [0x021F, 0x0224, "continuation_transfer"],
		[0x0224, 0x0229, "script_transfer"], [0x0229, 0x022F, "global_u8_write_run"],
		[0x022F, 0x0235, "global_u8_write_run"], [0x0235, 0x023B, "global_u8_write_run"],
	]:
		rows.append({"offset": row[0], "end_offset": row[1], "op": row[2]})
	for index in range(10):
		rows.append({"offset": 0x023B + index * 5, "end_offset": 0x0240 + index * 5, "op": "source_line_marker"})
	return rows


func _source_line_rows() -> Array:
	var rows := []
	for line in range(2, 24): rows.append([0x0062 + (line - 2) * 5, line])
	rows.append_array([[0x0112, 24], [0x011E, 25]])
	for line in range(26, 30): rows.append([0x012A + (line - 26) * 5, line])
	rows.append_array([[0x0148, 30], [0x0157, 31], [0x01B9, 32], [0x01BE, 33]])
	for line in range(34, 44): rows.append([0x023B + (line - 34) * 5, line])
	return rows


func _normalize_partition(value: Variant) -> Dictionary:
	if not value is Array or value.size() != RECORD_COUNT:
		return _error("Synthetic prefix partition requires exactly 103 records.")
	var expected := _expected_rows()
	var records: Array[Dictionary] = []
	for order in range(expected.size()):
		var row: Variant = value[order]
		if not row is Dictionary or row.size() != 5:
			return _error("Synthetic prefix record shape changed.")
		for key in row:
			if typeof(key) != TYPE_STRING or key not in ["order", "offset", "end_offset", "op", "sha256"]:
				return _error("Synthetic prefix record contains an unknown field.")
		var source: Dictionary = row
		var target: Dictionary = expected[order]
		if (
			typeof(source.get("order")) != TYPE_INT
			or typeof(source.get("offset")) != TYPE_INT
			or typeof(source.get("end_offset")) != TYPE_INT
			or typeof(source.get("op")) != TYPE_STRING
			or int(source.order) != order
			or int(source.offset) != int(target.offset)
			or int(source.end_offset) != int(target.end_offset)
			or str(source.op) != str(target.op)
		):
			return _error("Synthetic prefix record %d boundary changed." % order)
		if typeof(source.get("sha256")) != TYPE_STRING:
			return _error("Synthetic prefix record hash is malformed.")
		var hash := str(source.sha256)
		if not _is_lower_hex_digest(hash):
			return _error("Synthetic prefix record hash is malformed.")
		records.append(source.duplicate(true))
	return {"ok": true, "records": records}


func _entry_layout_matches(document: Dictionary) -> bool:
	var entries: Array = document.get("entries", [])
	if entries.size() != 426:
		return false
	var entry: Dictionary = entries[0]
	return int(entry.get("index", -1)) == 0 and int(entry.get("offset", -1)) == PREFIX_OFFSET and int(entry.get("end_offset", -1)) == ENTRY_ZERO_END


func _entry_label(record: Dictionary, index: int) -> bool:
	var operands: Array = record.get("operands", [])
	return operands.size() == 1 and int(operands[0].get("value", -1)) == index


func _source_line(record: Dictionary, line: int) -> bool:
	return _entry_label(record, line)


func _literal_record(record: Dictionary, value: int) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 1:
		return false
	var rows: Array = operands[0].get("records", [])
	return rows.size() == 1 and str(rows[0].get("type", "")) == "expression_record" and _signature(rows[0].get("value", {}).get("ast", {})) == value


func _simple_write(record: Dictionary, index: int, value_signature: Variant) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 2 or int(operands[0].get("value", -1)) != index:
		return false
	return _pairs_match(operands[1], value_signature)


func _banked_write(record: Dictionary, index_signature: Variant, bank: int, value_signature: Variant) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 3 or _signature(operands[0].get("value", {}).get("ast", {})) != index_signature or int(operands[1].get("value", -1)) != bank:
		return false
	return _pairs_match(operands[2], value_signature)


func _pairs_match(operand: Dictionary, value_signature: Variant) -> bool:
	var pairs: Array = operand.get("pairs", [])
	return pairs.size() == 1 and int(pairs[0].get("continuation", -1)) == 0 and _signature(pairs[0].get("expression", {}).get("ast", {})) == value_signature


func _branch(record: Dictionary, predicate: Variant, false_offset: int) -> bool:
	var operands: Array = record.get("operands", [])
	return operands.size() == 2 and _signature(operands[0].get("value", {}).get("ast", {})) == predicate and int(operands[1].get("value", -1)) == false_offset


func _continuation(record: Dictionary, target: int) -> bool:
	var operands: Array = record.get("operands", [])
	return operands.size() == 1 and int(operands[0].get("value", -1)) == target


func _loop_copy(record: Dictionary) -> bool:
	return _banked_write(record, ["add", 31, _state_ref("state_u16", 2)], 0, _state_ref("banked_u16", ["add", 168, _state_ref("state_u16", 2)]))


func _ax_selector(record: Dictionary, selector: int) -> bool:
	var operands: Array = record.get("operands", [])
	return operands.size() == 1 and int(operands[0].get("presentation_subcommand", -1)) == 3 and int(operands[0].get("execution_selector", -1)) == selector


func _native_records(record: Dictionary, values: Array) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 1:
		return false
	var rows: Array = operands[0].get("records", [])
	if rows.size() != values.size():
		return false
	for index in range(rows.size()):
		if str(rows[index].get("type", "")) != "expression_record" or _signature(rows[index].get("value", {}).get("ast", {})) != values[index]:
			return false
	return true


func _native_record_values(offset: int) -> Array:
	match offset:
		0x01A1: return [6, 2]
		0x01A9: return [6, 6]
		0x01B1: return [6, 10]
	return []


func _surface_operation(record: Dictionary) -> bool:
	var operands: Array = record.get("operands", [])
	if operands.size() != 1 or int(operands[0].get("presentation_subcommand", -1)) != 11 or int(operands[0].get("mode", -1)) != 0:
		return false
	var signatures := []
	for expression in operands[0].get("expressions", []): signatures.append(_signature(expression.get("ast", {})))
	return signatures == [0, 0, 0, 639, 399, 1, 0, 0, _state_ref("banked_u16", 23)]


func _state_ref(storage: String, index: Variant) -> Array:
	return ["state_ref", storage, 0, index]


func _signature(ast: Dictionary, depth := 0) -> Variant:
	if depth > 32:
		return null
	match str(ast.get("type", "")):
		"literal": return ast.get("value")
		"state_ref": return ["state_ref", str(ast.get("storage", "")), int(ast.get("bank", -1)), _signature(ast.get("index", {}), depth + 1)]
		"binary": return [str(ast.get("op", "")), _signature(ast.get("lhs", {}), depth + 1), _signature(ast.get("rhs", {}), depth + 1)]
		"call":
			var arguments := []
			for argument in ast.get("args", []): arguments.append(_signature(argument, depth + 1))
			return ["call", str(ast.get("name", "")), arguments]
	return null


func _record_hash(records: Dictionary, offset: int) -> String:
	return str(records.get(offset, {}).get("sha256", ""))


func _partition_fingerprint(records: Array) -> String:
	return ContractValues.sha256(JSON.stringify(records, "", true, true).to_utf8_buffer())


func _is_lower_hex_digest(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


func _same_plan_value(actual: Variant, expected: Variant, depth := 0) -> bool:
	if depth > 32:
		return false
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size(): return false
		for key in actual:
			if typeof(key) != TYPE_STRING or not expected.has(key) or not _same_plan_value(actual[key], expected[key], depth + 1): return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size(): return false
		for index in range(expected.size()):
			if not _same_plan_value(actual[index], expected[index], depth + 1): return false
		return true
	if typeof(expected) == TYPE_INT:
		if typeof(actual) == TYPE_FLOAT: return is_finite(float(actual)) and float(actual) == floor(float(actual)) and float(actual) == float(expected)
		return typeof(actual) == TYPE_INT and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
