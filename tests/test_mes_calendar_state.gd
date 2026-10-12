extends "res://tests/test_case.gd"

const CalendarStateScript := preload("res://content_core/mes_calendar_state.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const MesRecordGrammar := preload("res://tests/mes_record_grammar.gd")


func _ready() -> void:
	var calendar := CalendarStateScript.new()
	var document := _synthetic_start_document()
	var projection := calendar.build(document)
	_check(
		projection.ok
		and projection.schema == "kakyu_mes_calendar_state/v1"
		and projection.native_relative_base == 0x24A0
		and projection.row_count == 12
		and projection.row_stride == 32
		and projection.sentinel == 15
		and projection.table_bytes.size() == 384,
		"calendar state projection retains the bounded native table contract"
	)
	_check(
		projection.serialization_policy == "runtime_only_contains_original_derived_bytes"
		and projection.source_entry_sha256 == "synthetic-start"
		and not projection.source_mutated,
		"calendar state projection labels its runtime-only source policy"
	)
	var table: PackedByteArray = projection.table_bytes
	_check(table[30] == 2 and table[31] == 15, "first synthetic row retains a sentinel after 31 values")
	_check(table[32 + 27] == 3 and table[32 + 28] == 15, "second synthetic row retains a sentinel after 28 values")

	var state := SandboxStateScript.new(1)
	var applied := calendar.apply_to_state(projection, state)
	_check(
		applied.ok
		and state.native_relative_u8_aliases_enabled()
		and state.read_value("banked_u16", 0, 0) == 0x24A0,
		"calendar projection explicitly enables the audited relative base"
	)
	state.write_value("state_u16", 25, 0x24A0 + 32)
	_check(state.read_value("banked_u8", 28, 25) == 15, "DEF12-style bank 25 reads the projected month sentinel")
	_check(
		state.to_records().size() == 1,
		"runtime calendar baseline stays out of authored sandbox records"
	)

	var changed := document.duplicate(true)
	var changed_code: PackedByteArray = document.bytecode.duplicate()
	changed_code[0x0611] = 0x07
	changed["bytecode"] = changed_code
	var rejected := calendar.build(changed)
	_check(not rejected.ok and str(rejected.error).contains("row 1"), "calendar projection rejects a changed row opcode")

	var tampered := projection.duplicate(true)
	var tampered_table: PackedByteArray = projection.table_bytes.duplicate()
	tampered_table[0] = 14
	tampered["table_bytes"] = tampered_table
	_check(not calendar.apply_to_state(tampered, SandboxStateScript.new(1)).ok, "calendar apply rejects changed derived bytes")

	state.clear_native_relative_u8_layout()
	_check(
		not state.native_relative_u8_aliases_enabled()
		and state.read_value("banked_u16", 0, 0) == 0
		and state.read_value("relative_u8", 0x24A0 + 31) == 0,
		"clearing the native layout removes its word and byte baselines"
	)
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _synthetic_start_document() -> Dictionary:
	var code := PackedByteArray()
	code.resize(0x0B00)
	code.fill(0)
	_write_at(code, 0x05DF, PackedByteArray([0x04, 0x00, 0x00, 0xA0, 0x00, 0xFF, 0x00]))
	_write_at(code, 0x05FC, MesRecordGrammar.calendar_fill_write(CalendarStateScript.SENTINEL))
	for row_index in range(CalendarStateScript.ROW_COUNT):
		_write_at(
			code,
			int(CalendarStateScript.ROW_OFFSETS[row_index]),
			_row_instruction(row_index, int(CalendarStateScript.ROW_LENGTHS[row_index]))
		)
	return {
		"ok": true,
		"header": {"code_size": code.size()},
		"bytecode": code,
		"entry_sha256": "synthetic-start",
		"source": {"entry": "START.MES"},
	}


func _row_instruction(row_index: int, length: int) -> PackedByteArray:
	var result := PackedByteArray([0x06])
	var start := row_index * 32
	if start < 0x80:
		result.append(start)
	else:
		result.append_array(PackedByteArray([0xF1, start & 0xFF, (start >> 8) & 0xFF]))
	result.append(0xFF)
	result.append(0)
	for index in range(length):
		result.append(index % 4)
		result.append(0xFF)
		result.append(0 if index == length - 1 else 1)
	return result


func _write_at(target: PackedByteArray, offset: int, value: PackedByteArray) -> void:
	for index in range(value.size()):
		target[offset + index] = value[index]
