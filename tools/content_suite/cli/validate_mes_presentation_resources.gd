extends SceneTree

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")

const ENTRY_NAME := "D_PIC.MES"
const EXPECTED := {
	0x00CC: "D.MMO",
	0x0172: "D5.MMO",
	0x023C: "D1.MMO",
	0x02E6: "D2.MMO",
	0x0390: "D3.MMO",
	0x043A: "D4.MMO",
}


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		push_error("Usage: --script res://tools/content_suite/cli/validate_mes_presentation_resources.gd -- <mes.arc> [mmo.arc]")
		quit(2)
		return
	var reader := ArcReaderScript.new()
	if not reader.open(arguments[0]):
		push_error(reader.last_error)
		quit(1)
		return
	var entry_sha := reader.get_entry_fingerprint(ENTRY_NAME)
	var document := MesContainerScript.new().parse(reader.read_entry(ENTRY_NAME), {"entry": ENTRY_NAME})
	if not document.ok:
		push_error(str(document.error))
		reader.close()
		quit(1)
		return
	var decoder := DecoderScript.new()
	var mmo_reader = null
	if arguments.size() == 2:
		mmo_reader = ArcReaderScript.new()
		if not mmo_reader.open(arguments[1]):
			push_error(mmo_reader.last_error)
			reader.close()
			quit(1)
			return
	for offset in EXPECTED:
		var instruction := decoder.decode_at(document.bytecode, int(offset), int(document.header.code_size))
		if not instruction.ok or str(instruction.op) != "mmo_resource_marker" or str(instruction.operands[0].name).to_upper() != str(EXPECTED[offset]):
			push_error("D_PIC presentation mismatch at 0x%04X." % int(offset))
			reader.close()
			quit(1)
			return
		var resource_name := str(instruction.operands[0].name)
		var detail := ""
		if mmo_reader != null:
			var decoded := MmoCodecScript.new().decode_image(mmo_reader.read_entry(resource_name))
			if not decoded.ok:
				push_error("%s decode failed: %s" % [resource_name, str(decoded.error)])
				mmo_reader.close()
				reader.close()
				quit(1)
				return
			detail = " dimensions=%dx%d" % [int(decoded.width), int(decoded.height)]
		print("MMO_RESOURCE offset=0x%04X name=%s%s" % [int(offset), resource_name, detail])
	if mmo_reader != null:
		mmo_reader.close()
	reader.close()
	print("D_PIC entry_sha256=%s" % entry_sha)
	print("MES_PRESENTATION_RESOURCE_VALIDATION_PASS")
	quit(0)
