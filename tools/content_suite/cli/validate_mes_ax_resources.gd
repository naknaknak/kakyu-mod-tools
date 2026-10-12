extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const AxDwordStreamScript := preload("res://content_core/ax_dword_stream.gd")

const EXPECTED := {
	"01M.MES": {0x12720: "B19.AX"},
	"03C.MES": {0x0239: "W.AX", 0x3BBB: "W.AX"},
}
const EXPECTED_BINDINGS := {
	"01M.MES": {0x1274B: 0},
	"03C.MES": {0x0262: 0, 0x3BE4: 0},
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Usage: --script res://tools/content_suite/cli/validate_mes_ax_resources.gd -- <mes.arc> <data.arc>")
		quit(2)
		return
	var mes_reader := ArcReaderScript.new()
	var data_reader := ArcReaderScript.new()
	if not mes_reader.open(arguments[0]) or not data_reader.open(arguments[1]):
		push_error("MES_AX_RESOURCE_FAIL reader: %s %s" % [mes_reader.last_error, data_reader.last_error])
		quit(1)
		return
	var mes_sha := mes_reader.get_archive_fingerprint()
	var data_sha := data_reader.get_archive_fingerprint()
	var decoder := DecoderScript.new()
	var ax_reader := AxDwordStreamScript.new()
	var checked := 0
	for entry_name in EXPECTED:
		var document := MesContainerScript.new().parse(mes_reader.read_entry(entry_name), {"entry": entry_name})
		if not document.ok:
			_fail("%s parse: %s" % [entry_name, str(document.error)], mes_reader, data_reader)
			return
		for offset in EXPECTED[entry_name]:
			var expected_name := str(EXPECTED[entry_name][offset])
			var instruction := decoder.decode_at(document.bytecode, int(offset), int(document.header.code_size))
			if (
				not instruction.ok
				or str(instruction.op) != "ax_resource_marker"
				or str(instruction.operands[0].name) != expected_name
				or int(instruction.command_id) != 0x0D
				or int(instruction.operands[0].presentation_subcommand) != 8
				or int(instruction.operands[0].execution_selector) != 0
				or int(instruction.operands[0].data_archive_index) != 0
				or str(instruction.operands[0].native_consumer_semantics) != "data_arc_named_entry_load_confirmed"
				or str(instruction.operands[0].native_loader_argument) != "banked_i32[0][2]"
				or str(instruction.operands[0].native_loader_argument_semantics) != "engine_initialized_destination_buffer_pointer"
				or str(instruction.operands[0].native_payload_semantics) != "unresolved"
			):
				_fail("%s marker mismatch at 0x%X" % [entry_name, int(offset)], mes_reader, data_reader)
				return
			var inspected := ax_reader.inspect(data_reader.read_entry(expected_name))
			if not inspected.ok:
				_fail("%s structure: %s" % [expected_name, str(inspected.error)], mes_reader, data_reader)
				return
			checked += 1
			print("AX_RESOURCE entry=%s offset=0x%X name=%s tokens=%d" % [entry_name, int(offset), expected_name, int(inspected.token_count)])
		for offset in EXPECTED_BINDINGS.get(entry_name, {}):
			var expected_column := int(EXPECTED_BINDINGS[entry_name][offset])
			var binding := decoder.decode_at(document.bytecode, int(offset), int(document.header.code_size))
			if (
				not binding.ok
				or str(binding.op) != "ax_presentation_binding"
				or int(binding.command_id) != 0x0D
				or int(binding.operands[0].presentation_subcommand) != 3
				or int(binding.operands[0].execution_selector) != 0
				or int(binding.operands[0].consumer_index) != 0
				or int(binding.operands[0].consumer_virtual_slot) != 0x08
				or int(binding.operands[0].cell_row) != 0
				or int(binding.operands[0].cell_column) != expected_column
				or str(binding.operands[0].buffer_argument) != "banked_i32[0][2]"
				or int(binding.operands[0].binding_table_entries) != 320
				or int(binding.operands[0].binding_table_bytes) != 0x500
				or str(binding.operands[0].native_consumer_semantics) != "ax_binding_table_cell_install_confirmed"
				or str(binding.operands[0].native_rendering_semantics) != "unresolved"
			):
				_fail("%s binding mismatch at 0x%X" % [entry_name, int(offset)], mes_reader, data_reader)
				return
			checked += 1
			print("AX_BINDING entry=%s offset=0x%X cell=(0,%d)" % [entry_name, int(offset), expected_column])
	if mes_reader.get_archive_fingerprint() != mes_sha or data_reader.get_archive_fingerprint() != data_sha:
		_fail("source archive hash changed", mes_reader, data_reader)
		return
	mes_reader.close()
	data_reader.close()
	print("MES_AX_RESOURCE_VALIDATION_PASS records=%d sources_unchanged=true" % checked)
	quit(0)


func _fail(message: String, mes_reader, data_reader) -> void:
	push_error("MES_AX_RESOURCE_FAIL %s" % message)
	mes_reader.close()
	data_reader.close()
	quit(1)
