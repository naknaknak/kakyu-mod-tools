extends "res://tools/content_suite/cli/audit_eventb03_state12.gd"

# Reuse the zero-entry, original-Core result-2 walker, not Event Player or a
# Python projection. New boundaries still fail closed in the inherited walker.
const AFFECTION_INPUTS := [0, 5, 6, 35, 36, 75, 76, 65535]
const AFFECTION_GUARD_SHA256 := "76832232e1c731536ac40ed11f91996a0757380f0b8191a722f9b71acff06266"
# Core 0.316.0 (2026-09-13): an MMO marker is the whole System.function[9] call,
# so each face profile's marker offset is the 0x0D byte before the 09.
const FACE_PROFILES := {
	1: {"mmo": 0x05B5, "ax": 0x05C9, "binding": 0x05F2, "active": 0x0604, "active_end": 0x0611, "trace": PICTURE_TRACE_SHA256},
	0: {"mmo": 0x0651, "ax": 0x0665, "binding": 0x068E, "active": 0x06A0, "active_end": 0x06AD, "trace": "0626c326e9c04e484c8948a06b52097e51d285c924ecd94264462d77d8f27748"},
	2: {"mmo": 0x06ED, "ax": 0x0701, "binding": 0x072A, "active": 0x073C, "active_end": 0x0749, "trace": "b7f9d33140a854267d252ab2ac467536a3fb190553500b8c459db9229db8ca58"},
}


func _audit() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: <ELFIMAGE-directory>")
		quit(1)
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before_hashes := {}
	for archive in ["mes.arc", "mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc"]:
		var path := source_root.path_join(archive)
		if not FileAccess.file_exists(path):
			push_error("Required original archive is unavailable: %s" % archive)
			quit(1)
			return
		before_hashes[archive] = FileAccess.get_sha256(path)
	_check(before_hashes["mes.arc"] == MES_SHA256, "mes.arc identity changed")
	if _failures.is_empty():
		_check(_reader.open(source_root.path_join("mes.arc")), "original mes.arc could not be opened")
	if _failures.is_empty():
		_load_documents()
	if _failures.is_empty():
		_validate_source_records()
		_validate_affection_records()
	if _failures.is_empty():
		for initial_state12 in [0, 100]:
			for initial_affection in AFFECTION_INPUTS:
				_validate_affection_case(initial_state12, initial_affection)
	_reader.close()
	for archive in before_hashes:
		_check(FileAccess.get_sha256(source_root.path_join(archive)) == before_hashes[archive], "%s changed during audit" % archive)
	if not _failures.is_empty():
		push_error("EVENTB03 affection audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: EVENTB03 result 2 affection source audit: %d checks; 16 original zero-entry routes, clamp and face threshold neighbors, exact 20/18-dialogue suffixes, B_PIC trace/media/state, MACHI terminals and complete final diffs; six archives unchanged. Core %s / %s. Not native GUI/cadence, event eligibility, or authorization of every audited preset." % [_checks, CoreVersion.CORE_VERSION, CoreVersion.MES_INSTRUCTION_SCHEMA])
	quit(0)


func _validate_affection_records() -> void:
	var code: PackedByteArray = _documents["EVENTB03.MES"].bytecode
	_check(_sha256(code.slice(0x2083, 0x20B5)) == AFFECTION_GUARD_SHA256, "affection guard/write envelope changed")
	var guard := Decoder.new().decode_at_structural(code, 0x2083)
	_check(guard.get("ok", false) and guard.get("op", "") == "branch_if_not_true" and guard.get("end_offset", -1) == 0x2098, "affection guard boundary changed")
	if not guard.get("ok", false):
		return
	var ast: Dictionary = guard.operands[0].value.ast
	_check(ast.get("op", "") == "logical_and" and _affection_compare(ast.get("lhs", {}), "greater_than", 5) and _affection_compare(ast.get("rhs", {}), "not_equal", 0) and guard.operands[1].value == 0x20AC, "affection clamp expression changed")
	for record in [[0x2098, 0x20A7], [0x20AC, 0x20B5]]:
		var write := Decoder.new().decode_at_structural(code, record[0])
		_check(write.get("ok", false) and write.get("op", "") == "banked_u16_write_run" and write.get("end_offset", -1) == record[1], "affection write boundary changed")
		if not write.get("ok", false):
			continue
		_check(write.operands[0].value.ast.get("value", -1) == 210 and write.operands[1].value == 0 and write.operands[2].pairs.size() == 1, "affection destination changed")
		var value: Dictionary = write.operands[2].pairs[0].expression.ast
		_check(_affection_compare(value, "subtract", 5) if record[0] == 0x2098 else value.get("type", "") == "literal" and value.get("value", -1) == 0, "affection write value changed")
	var picture_code: PackedByteArray = _documents["B_PIC.MES"].bytecode
	for span in [[0x0568, 0x0597, "99225c4ef202a59916b295d2ae7016c0a6576d7723a2f7147981ef9a420206cd"], [0x0626, 0x0633, "6cf3462a3011c23d41a8c08876ef414a24b18a2afcc9321d65cbef76dcb9275d"], [0x06C2, 0x06CF, "07b3b36a44729cd3569d0c6c408fb4718f2fad933ac8815f154a9806a34398d1"]]:
		var face_guard := Decoder.new().decode_at_structural(picture_code, span[0])
		_check(_sha256(picture_code.slice(span[0], span[1])) == span[2] and face_guard.get("ok", false) and face_guard.get("op", "") == "branch_if_not_true" and face_guard.get("end_offset", -1) == span[1], "face guard envelope changed at 0x%X" % span[0])
		if face_guard.get("ok", false) and span[0] != 0x0568:
			_check(_affection_compare(face_guard.operands[0].value.ast, "less_than" if span[0] == 0x0626 else "greater_than", 71 if span[0] == 0x0626 else 70) and face_guard.operands[1].value == (0x06C2 if span[0] == 0x0626 else 0x0759), "face threshold expression changed")
	for column in FACE_PROFILES:
		var profile: Dictionary = FACE_PROFILES[column]
		for record in [[profile.binding, profile.active, "ax_presentation_binding"], [profile.active, profile.active_end, "ax_presentation_control"]]:
			var decoded := Decoder.new().decode_at_structural(picture_code, record[0])
			_check(decoded.get("ok", false) and decoded.get("op", "") == record[2] and decoded.get("end_offset", -1) == record[1] and decoded.operands[0].get("cell_row", -1) == 0 and decoded.operands[0].get("cell_column", -1) == column and decoded.operands[0].get("execution_selector", -1) == (0 if record[0] == profile.binding else 1), "face compound record boundary changed at 0x%X" % record[0])


func _validate_affection_case(initial_state12: int, initial_affection: int) -> void:
	_events.clear()
	_trace.clear()
	var state := State.new(1)
	for pair in [[4, 6], [7, 413], [12, initial_state12], [19, 1825]]:
		state.write_value("state_u16", pair[0], pair[1])
	state.write_value("banked_u16", 210, initial_affection, 0)
	var before := state.snapshot()
	var result := _walk("EVENTB03.MES", state, 0)
	var label := "state12 %d / affection %d" % [initial_state12, initial_affection]
	_check(result.get("ok", false), "%s stopped at an unexpected boundary" % label)
	if not result.get("ok", false):
		return
	var final_affection := maxi(initial_affection - 5, 0)
	var column := 1 if final_affection < 31 else (0 if final_affection < 71 else 2)
	var profile: Dictionary = FACE_PROFILES[column]
	var root_events := _events.filter(func(row): return row.entry == "EVENTB03.MES")
	var prefix := root_events.filter(func(row): return row.status == "dialogue_boundary" and row.offset < 0x12D7).map(func(row): return row.offset)
	var suffix := root_events.filter(func(row): return row.status == "dialogue_boundary" and row.offset >= 0x12D7).map(func(row): return row.offset)
	var libraries := root_events.filter(func(row): return row.status == "shared_routine_boundary" and row.offset >= 0x12D7)
	var suffix_trace := _trace.filter(func(row): return row.entry == "EVENTB03.MES" and row.offset >= 0x12D7)
	var writes := _trace.filter(func(row): return row.get("write_storage", "") == "banked_u16" and row.get("write_start", -1) == 210)
	_check(prefix == PREFIX and suffix == (LOW_SUFFIX if initial_state12 == 0 else HIGH_SUFFIX), "%s dialogue route changed" % label)
	_check(libraries.map(func(row): return [row.offset, row.routine]) == SUFFIX_LIBRARIES and libraries.map(func(row): return row.arguments.get(1, -1)) == [1, 11, 11, 11, 11, 0, 11, 11, 11], "%s library route changed" % label)
	for library in libraries:
		if library.routine == 25:
			_check(library.omitted_native_records == 33, "%s shared DEF26 omission count changed" % label)
	_check(writes.size() == 1 and writes[0].entry == "EVENTB03.MES" and writes[0].offset == (0x2098 if initial_affection > 5 else 0x20AC), "%s affection write sequence changed" % label)
	_check(state.read_value("banked_u16", 210, 0) == final_affection, "%s final affection changed" % label)
	var pictures := root_events.filter(func(row): return row.status == "script_dispatch_boundary")
	_check(pictures.size() == 1 and pictures[0].offset == 0x2238 and pictures[0].resume == 0x2245 and pictures[0].state12 == 0 and pictures[0].banked251 == initial_state12, "%s B_PIC caller changed" % label)
	var picture_events := _events.filter(func(row): return row.entry == "B_PIC.MES")
	var picture_libraries := picture_events.filter(func(row): return row.status == "shared_routine_boundary")
	var returns := picture_events.filter(func(row): return row.status == "script_return")
	_check(picture_libraries.size() == 1 and picture_libraries[0].offset == 0x035B and picture_libraries[0].resume == 0x0360 and picture_libraries[0].routine == 22 and picture_libraries[0].arguments.get(1, -1) == 14, "%s B_PIC shared call changed" % label)
	var nested_diff: Array = _expected_picture_diff(2, column)
	if returns.size() == 1:
		print("B03_AFFECTION_PICTURE_DIAGNOSTIC %s column=%d return=0x%X trace=%s" % [label, column, int(returns[0].offset), str(returns[0].trace_sha256)])
	_check(returns.size() == 1 and returns[0].offset == 0x0759 and returns[0].end == 0x075A and returns[0].trace_sha256 == profile.trace and returns[0].nested_diff == nested_diff, "%s B_PIC trace/return/state changed" % label)
	var picture_trace := _trace.filter(func(row): return row.entry == "B_PIC.MES")
	var cells := picture_trace.filter(func(row): return row.has("cell_column"))
	_check(cells.map(func(row): return [row.offset, row.end, row.effect, row.cell_row, row.cell_column]) == [[profile.binding, profile.active, "ax_presentation_binding", 0, column], [profile.active, profile.active_end, "ax_selected_cell_state_0_omitted", 0, column]], "%s face binding/activation changed" % label)
	_check(picture_trace.filter(func(row): return row.has("resource_name")).map(func(row): return [row.offset, str(row.resource_name).to_upper()]) == [[0x00A0, "MAHOKO.WAV"], [0x02E4, "B1.MMO"], [profile.mmo, "BAN.MMO"], [profile.ax, "B.AX"]], "%s picture media changed" % label)
	_check(suffix_trace.filter(func(row): return row.has("resource_name")).map(func(row): return [row.offset, str(row.resource_name).to_upper()]) == [[0x225C, "B0811.OGG"], [0x232B, "B0812.OGG"], [0x2426, "B0813.OGG"], [0x24D7, "B0814.OGG"], [0x262E, "KSE0069.WAV"]], "%s root voice/effect resources changed" % label)
	_check(suffix_trace.filter(func(row): return "omitted" in row.effect).map(func(row): return [row.offset, row.end, row.effect]) == [[0x20DF, 0x20E6, "ax_cells_mark_active_omitted"], [0x20E6, 0x20ED, "ax_cells_activate_wait_omitted"], [0x25A4, 0x25AB, "ax_cells_mark_active_omitted"], [0x25AB, 0x25B2, "ax_cells_activate_wait_omitted"]], "%s root omissions changed" % label)
	_check(suffix_trace.filter(func(row): return row.effect == "effect_request" or row.has("surface_mode")).is_empty(), "%s introduced a routine9 effect or camera" % label)
	var terminal: Dictionary = result.terminal
	_check(terminal.status == "script_handoff_boundary" and terminal.offset == 0x26F4 and terminal.end == 0x2701 and terminal.target == "MACHI.MES", "%s terminal changed" % label)
	_check(state.read_value("state_u16", 12) == initial_state12 and state.read_value("banked_u16", 251, 0) == initial_state12, "%s state12 restoration changed" % label)
	_check(_diff_values(state.diff(before)) == _expected_final_diff(initial_state12, initial_affection, final_affection, column), "%s complete final state diff changed" % label)
	print("AFFECTION ", JSON.stringify({"initial_state12": initial_state12, "initial_affection": initial_affection, "final_affection": final_affection, "face_column": column, "suffix_dialogues": suffix.size(), "picture_trace_sha256": profile.trace, "terminal_offset": terminal.offset}))


func _affection_compare(ast: Dictionary, operation: String, literal: int) -> bool:
	return ast.get("op", "") == operation and _is_state_ref(ast.get("lhs", {}), "banked_u16", 210) and ast.get("rhs", {}).get("type", "") == "literal" and ast.get("rhs", {}).get("value", -1) == literal


func _diff_values(rows: Array) -> Dictionary:
	var values := {}
	for row in rows:
		values["%s/%d/%d" % [row.storage, row.bank, row.index]] = [row.before, row.after]
	return values


func _expected_final_diff(initial_state12: int, initial_affection: int, final_affection: int, column: int) -> Dictionary:
	var expected := {"banked_u16/0/1": [0, 7], "state_u16/0/21": [0, 2]}
	if initial_affection != final_affection:
		expected["banked_u16/0/210"] = [initial_affection, final_affection]
	if initial_state12 != 0:
		expected["banked_u16/0/251"] = [0, initial_state12]
	for index in [206, 286, 3688, 5306, 626, 631, 632]:
		expected["global_u8/0/%d" % index] = [0, 1]
	expected["global_u8/0/627"] = [0, 2]
	expected["global_i32/0/1"] = [0, FINAL_ARGUMENT[2]]
	if column != 0:
		expected["global_u8/0/3005"] = [0, column]
	return expected
