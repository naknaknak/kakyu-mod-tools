extends "res://tests/test_case.gd"

const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const MesRecordGrammar := preload("res://tests/mes_record_grammar.gd")


func _ready() -> void:
	var decoder := DecoderScript.new()

	var poll := MesRecordGrammar.map_location_poll()
	var poll_instruction := decoder.decode_at(poll, 0, poll.size())
	var poll_records: Array = poll_instruction.operands[0].records if poll_instruction.ok else []
	_check(
		poll_instruction.ok
		and poll_instruction.op == "native_record_dispatch"
		and poll_instruction.end_offset == poll.size()
		and poll_records.size() == 2
		and poll_records[0].value.ast.value == MesRecordGrammar.MAP_MODULE
		and poll_records[1].value.ast.value == MesRecordGrammar.MAP_GET_LOCATION,
		"the map location poll decodes as one native record dispatch of Util(6,13)"
	)
	_check(
		MesRecordGrammar.native_record_dispatch(MesRecordGrammar.MAP_MODULE, MesRecordGrammar.MAP_GET_LOCATION) == poll,
		"the poll is the generic dispatch builder applied to the map module and its location function"
	)

	var fill := MesRecordGrammar.calendar_fill_write(15)
	var fill_instruction := decoder.decode_at(fill, 0, fill.size())
	_check(
		fill_instruction.ok
		and fill_instruction.op == "banked_u8_write_run"
		and fill_instruction.end_offset == fill.size()
		and fill_instruction.operands[0].value.ast.storage == "state_u16"
		and fill_instruction.operands[0].value.ast.index.value == MesRecordGrammar.CALENDAR_FILL_STATE_U16_INDEX
		and fill_instruction.operands[1].value == MesRecordGrammar.BANK_ZERO
		and fill_instruction.operands[2].pairs.size() == 1
		and fill_instruction.operands[2].pairs[0].expression.ast.value == 15
		and fill_instruction.operands[2].pairs[0].continuation == MesRecordGrammar.CONTINUATION_NONE,
		"the calendar fill decodes as one bank-zero state_u16 byte write of its sentinel"
	)

	for selector in [2, 3]:
		var marker := MesRecordGrammar.resource_marker_head(selector)
		marker.append_array(("name.lib" if selector == 2 else "name.mes").to_ascii_buffer())
		marker.append_array(MesRecordGrammar.name_end_and_record_list_end())
		var marker_instruction := decoder.decode_at(marker, 0, marker.size())
		_check(
			marker_instruction.ok
			and marker_instruction.op == "inline_script_execution"
			and marker_instruction.end_offset == marker.size()
			and marker_instruction.operands[0].execution_selector == selector,
			"a script-execution marker built for selector %d decodes with that selector" % selector
		)

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
