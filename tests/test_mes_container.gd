extends "res://tests/test_case.gd"

const MesContainerScript := preload("res://content_core/mes_container.gd")


func _ready() -> void:
	var data := PackedByteArray()
	data.resize(4 + 8 + 12)
	data.fill(0)
	data.encode_u32(0, 2)
	data.encode_u32(4, 3)
	data.encode_u32(8, 8)
	for index in range(12):
		data[12 + index] = index + 1
	var parser := MesContainerScript.new()
	var parsed := parser.parse(data, {"entry": "SYNTHETIC.MES"})
	_check(parsed.ok, "synthetic MES container parses")
	_check(parsed.header.entry_count == 2, "MES address count decodes")
	_check(parsed.header.code_offset == 12 and parsed.header.code_size == 12, "MES code boundary decodes")
	_check(parsed.bootstrap.size == 3, "MES bootstrap prefix is retained")
	_check(parsed.entries[0].offset == 3 and parsed.entries[0].size == 5, "first MES address range decodes")
	_check(parsed.entries[1].offset == 8 and parsed.entries[1].size == 4, "final MES address range decodes")
	_check(parsed.bytecode == data.slice(12), "MES bytecode is retained losslessly")

	var library := PackedByteArray()
	library.resize(9)
	library.fill(0x44)
	library.encode_u32(0, 0)
	var library_result := parser.parse(library, {"entry": "LIBLARY.LIB"})
	_check(library_result.ok, "zero-address library container parses")
	_check(library_result.entries.is_empty(), "zero-address library has no fabricated entries")
	_check(library_result.bootstrap.size == 5, "zero-address library retains all code bytes")

	var truncated := PackedByteArray()
	truncated.resize(4)
	truncated.encode_u32(0, 2)
	_check(not parser.parse(truncated).ok, "truncated MES table is rejected")
	var unordered := data.duplicate()
	unordered.encode_u32(4, 8)
	unordered.encode_u32(8, 3)
	_check(not parser.parse(unordered).ok, "unordered MES addresses are rejected")
	var outside := data.duplicate()
	outside.encode_u32(8, 12)
	_check(not parser.parse(outside).ok, "out-of-range MES address is rejected")

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
