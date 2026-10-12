class_name KakyuMesCalendarState
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const ContractValues := preload("res://content_core/contract_values.gd")

const NATIVE_RELATIVE_BASE := 0x24A0
## SHA-256 of the 384-byte table the audited START.MES builder produces
## (`kakyu_mes_calendar_state_audit/v1`); a projection whose table hashes
## differently is not the original calendar and must not be seeded.
const AUDITED_TABLE_SHA256 := "f21ee0fcb09e960046878e35ad0410aed88680f849ace471b713ef7a12525b4a"
const ROW_STRIDE := 32
const ROW_COUNT := 12
const TABLE_SIZE := ROW_STRIDE * ROW_COUNT
const SENTINEL := 15
const ROW_OFFSETS := [0x0611, 0x0677, 0x06D4, 0x073A, 0x079D, 0x0805, 0x086A, 0x08D2, 0x093A, 0x099F, 0x0A07, 0x0A6C]
const ROW_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


func build(start_document: Dictionary) -> Dictionary:
	if not start_document.get("ok", false) or not start_document.get("bytecode", null) is PackedByteArray:
		return _error("A valid START.MES container document is required.")
	var code: PackedByteArray = start_document.bytecode
	var limit := mini(code.size(), int(start_document.get("header", {}).get("code_size", code.size())))
	if limit <= ROW_OFFSETS[-1]:
		return _error("START.MES bytecode does not cover the audited calendar rows.")
	var decoder := MesInstructionDecoderScript.new()
	var base_write := decoder.decode_at(code, 0x05DF, limit)
	var fill_write := decoder.decode_at(code, 0x05FC, limit)
	if not _matches_base_write(base_write):
		return _error("START.MES calendar base registration changed at 0x05DF.")
	if not _matches_fill_write(fill_write):
		return _error("START.MES calendar sentinel fill changed at 0x05FC.")

	var table := PackedByteArray()
	table.resize(TABLE_SIZE)
	table.fill(SENTINEL)
	var rows: Array[Dictionary] = []
	for row_index in range(ROW_COUNT):
		var instruction: Dictionary = decoder.decode_at(code, int(ROW_OFFSETS[row_index]), limit)
		var values := _row_values(instruction, row_index)
		if not values.get("ok", false):
			return _error(str(values.get("error", "Calendar row changed.")))
		var row_bytes: PackedByteArray = values.bytes
		var start := row_index * ROW_STRIDE
		for value_index in range(row_bytes.size()):
			table[start + value_index] = row_bytes[value_index]
		rows.append({
			"month": row_index + 1,
			"source_offset": int(ROW_OFFSETS[row_index]),
			"relative_start": start,
			"value_count": row_bytes.size(),
			"value_sha256": ContractValues.sha256_lenient(row_bytes),
		})

	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CALENDAR_STATE_SCHEMA,
		"serialization_policy": "runtime_only_contains_original_derived_bytes",
		"source_entry": str(start_document.get("source", {}).get("entry", "START.MES")),
		"source_entry_sha256": str(start_document.get("entry_sha256", "")),
		"native_relative_base": NATIVE_RELATIVE_BASE,
		"row_count": ROW_COUNT,
		"row_stride": ROW_STRIDE,
		"sentinel": SENTINEL,
		"row_lengths": ROW_LENGTHS.duplicate(),
		"rows": rows,
		"table_bytes": table,
		"table_sha256": ContractValues.sha256_lenient(table),
		"source_mutated": false,
	}


func apply_to_state(projection: Dictionary, state: KakyuMesSandboxState) -> Dictionary:
	if (
		not projection.get("ok", false)
		or str(projection.get("schema", "")) != ContentCoreVersionScript.MES_CALENDAR_STATE_SCHEMA
		or int(projection.get("native_relative_base", -1)) != NATIVE_RELATIVE_BASE
		or not projection.get("table_bytes", null) is PackedByteArray
	):
		return _error("A valid runtime-only calendar projection is required.")
	var table: PackedByteArray = projection.table_bytes
	if table.size() != TABLE_SIZE or str(projection.get("table_sha256", "")) != ContractValues.sha256_lenient(table):
		return _error("Calendar projection bytes do not match their bounded table contract.")
	if not state.write_relative_u8_block(NATIVE_RELATIVE_BASE, table):
		return _error("Calendar projection exceeds the sandbox relative-byte range.")
	if not state.set_native_banked_u16_zero_baseline(NATIVE_RELATIVE_BASE):
		return _error("Calendar projection could not seed the native bank-zero word base.")
	state.set_native_relative_u8_aliases_enabled(true)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.MES_CALENDAR_STATE_SCHEMA,
		"native_relative_base": NATIVE_RELATIVE_BASE,
		"table_sha256": str(projection.table_sha256),
		"aliases_enabled": true,
	}


func _matches_base_write(instruction: Dictionary) -> bool:
	if not instruction.get("ok", false) or int(instruction.get("command_id", -1)) != 0x04:
		return false
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2 or int(operands[0].get("value", -1)) != 0:
		return false
	var pairs: Array = operands[1].get("pairs", [])
	return pairs.size() == 1 and _is_state_ref(pairs[0].get("expression", {}).get("ast", {}), "banked_u16", 0, 0)


func _matches_fill_write(instruction: Dictionary) -> bool:
	if not instruction.get("ok", false) or int(instruction.get("command_id", -1)) != 0x06:
		return false
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 3 or int(operands[1].get("value", -1)) != 0:
		return false
	var destination: Dictionary = operands[0].get("value", {})
	var pairs: Array = operands[2].get("pairs", [])
	return (
		_is_state_ref(destination.get("ast", {}), "state_u16", 0, 8)
		and pairs.size() == 1
		and _literal_value(pairs[0].get("expression", {})) == SENTINEL
		and int(pairs[0].get("continuation", -1)) == 0
	)


func _row_values(instruction: Dictionary, row_index: int) -> Dictionary:
	if not instruction.get("ok", false) or int(instruction.get("command_id", -1)) != 0x06:
		return _error("START.MES calendar row %d is not command 0x06." % (row_index + 1))
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 3 or int(operands[1].get("value", -1)) != 0:
		return _error("START.MES calendar row %d changed its bank." % (row_index + 1))
	if _literal_value(operands[0].get("value", {})) != row_index * ROW_STRIDE:
		return _error("START.MES calendar row %d changed its relative start." % (row_index + 1))
	var pairs: Array = operands[2].get("pairs", [])
	if pairs.size() != int(ROW_LENGTHS[row_index]):
		return _error("START.MES calendar row %d changed its length." % (row_index + 1))
	var values := PackedByteArray()
	for pair_index in range(pairs.size()):
		var pair: Dictionary = pairs[pair_index]
		var value := _literal_value(pair.get("expression", {}))
		var expected_continuation := 0 if pair_index == pairs.size() - 1 else 1
		if value < 0 or value >= SENTINEL or int(pair.get("continuation", -1)) != expected_continuation:
			return _error("START.MES calendar row %d has an invalid value run." % (row_index + 1))
		values.append(value)
	return {"ok": true, "bytes": values}


func _literal_value(expression: Dictionary) -> int:
	var ast: Dictionary = expression.get("ast", {})
	if str(ast.get("type", "")) != "literal":
		return -1
	return int(ast.get("value", -1))


func _is_state_ref(ast: Dictionary, storage: String, bank: int, index: int) -> bool:
	var index_ast: Dictionary = ast.get("index", {})
	return (
		str(ast.get("type", "")) == "state_ref"
		and str(ast.get("storage", "")) == storage
		and int(ast.get("bank", 0)) == bank
		and str(index_ast.get("type", "")) == "literal"
		and int(index_ast.get("value", -1)) == index
	)


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"schema": ContentCoreVersionScript.MES_CALENDAR_STATE_SCHEMA,
		"error": message,
	}
