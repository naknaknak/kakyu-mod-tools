extends "res://tests/test_case.gd"

const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")


func _ready() -> void:
	var code := PackedByteArray([0x1F, 2, 0, 0, 0])
	SyntheticArc.append_registration(code, 3, PackedByteArray([0x01, 0x41, 0x00, 0x00]))
	SyntheticArc.append_registration(code, 7, PackedByteArray([0x0D, 0x00]))
	code.append(0x00)
	var index := LibraryIndexScript.new().build(code)
	_check(index.ok and index.get("schema", "") == "kakyu_mes_library_index/v1", "library registration chain builds a versioned index: %s" % str(index.get("error", "ok")))
	if index.ok:
		_check(index.registration_count == 2 and index.terminal_offset == code.size() - 1, "library index follows forward skip targets to the terminal return")
		_check(index.routines[0].routine_id == 3 and index.routines[0].size == 4, "first routine retains its exact body bounds")
		_check(index.by_id[7].body_offset + 2 == index.by_id[7].end_offset, "library index exposes stable lookup by literal routine ID")

	var duplicate := PackedByteArray()
	SyntheticArc.append_registration(duplicate, 3, PackedByteArray([0x00]))
	SyntheticArc.append_registration(duplicate, 3, PackedByteArray([0x00]))
	duplicate.append(0x00)
	_check(not LibraryIndexScript.new().build(duplicate).ok, "duplicate library routine IDs are rejected")

	var backward := PackedByteArray([0x1C, 0x01, 0xFF, 0, 0, 0, 0, 0x00])
	_check(not LibraryIndexScript.new().build(backward).ok, "backward library skip targets are rejected")

	var nonliteral := PackedByteArray([0x1C, 0xF6, 0x00, 0x00, 0xFF, 9, 0, 0, 0, 0x00])
	_check(not LibraryIndexScript.new().build(nonliteral).ok, "nonliteral library routine registrations are rejected")
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
