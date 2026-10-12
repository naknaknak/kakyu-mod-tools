extends "res://tools/content_suite/cli/audit_eventb03_preset_choices.gd"

# Audit-only flag states: this file does not authorize Event Player presets.
const FLAGS := [204, 207, 628]
const FLAG_GUARD_SHA256 := "99225c4ef202a59916b295d2ae7016c0a6576d7723a2f7147981ef9a420206cd"
# Core 0.316.0 (2026-09-13): outer traces are taken over the system-call
# framing; the boundaries, writes and media rows they summarize are unchanged.
# Core 0.377.0 (TD-56): the outer traces carry each command-0x09 row's write fields
# and the library rows of the arms the real selector picks (routine 28's selector-1
# arm skips the routine-21 call at 0x0225; routine 9's calls no longer walk the
# whole selector-0 ladder); results 1 and 3 equal the preset audit's pins.
const OUTER_TRACES := {
	1: [899, "c7ff76ac27946e64ede9b6be1a45e3b00320fba9a9350265a2247795f98ff753"],
	2: [902, "ca4638b8994b4a1ae172f0fc550828338409a5851f2cb229b1b47b034522e17e"],
	3: [1446, "3e626e47d8c1ae7008f638b910c5d7031b9a21906739cb059384e0c133046a34"],
}
var _picture_input := {}
var _conditions: Array[Dictionary] = []
var _matrix: Array[Dictionary] = []


func _audit() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: <ELFIMAGE-directory>")
		quit(1)
		return
	var root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before_hashes := {}
	for archive in ["mes.arc", "mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc"]:
		var path := root.path_join(archive)
		if not FileAccess.file_exists(path):
			push_error("Required original archive unavailable: %s" % archive)
			quit(1)
			return
		before_hashes[archive] = FileAccess.get_sha256(path)
	_check(before_hashes["mes.arc"] == MES_SHA256, "original mes.arc identity changed")
	if _failures.is_empty():
		_check(_reader.open(root.path_join("mes.arc")), "original mes.arc unavailable")
	if _failures.is_empty():
		_load_documents()
	if _failures.is_empty():
		_validate_source_records()
		_validate_affection_records()
		_validate_additional_records()
		_validate_flag_guard()
	if _failures.is_empty():
		for row in _cases():
			_validate_flag_case(row)
		_validate_matrix_distinctions()
	_reader.close()
	for archive in before_hashes:
		_check(FileAccess.get_sha256(root.path_join(archive)) == before_hashes[archive], "%s changed during audit" % archive)
	if not _failures.is_empty():
		push_error("EVENTB03 face flags audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	for choice in [1, 2, 3]:
		var rows := _matrix.filter(func(row): return row.choice == choice)
		print("FACE_FLAGS ", JSON.stringify({"choice": choice, "routes": rows.size(), "face_columns": rows.map(func(row): return row.column), "outer_trace_sha256": OUTER_TRACES[choice][1]}))
	print("PASS: EVENTB03 face flag source audit: %d checks / %d zero-entry routes; all 204/207/628 boolean combinations, post-choice 70/71 and 80/81 neighbors, noncanonical 2/255, exact guard AST, unchanged outer traces, face trace/binding, flag preservation and complete final diffs; six archives unchanged. Core %s / %s. Audit-only: no new playback preset, native GUI/cadence or host-eligibility claim." % [_checks, _matrix.size(), CoreVersion.CORE_VERSION, CoreVersion.MES_INSTRUCTION_SCHEMA])
	quit(0)


func _cases() -> Array:
	var rows := {}
	for choice in [1, 2, 3]:
		for mask in range(8):
			var flags := [mask & 1, (mask >> 1) & 1, (mask >> 2) & 1]
			_case_add(rows, choice, 76, flags)
		for output in [70, 71, 80, 81]:
			var initial: int = output + 5 if choice == 2 else output - (2 if choice == 1 else 3)
			_case_add(rows, choice, initial, [0, 0, 0])
			_case_add(rows, choice, initial, [0, 0, 1] if output < 80 else [0, 1, 0])
		for value in [2, 255]:
			for flag in range(3):
				var flags := [0, 0, 0]
				flags[flag] = value
				_case_add(rows, choice, 76, flags)
				# At output >=71, flag 628 would not distinguish 1 from 2/255.
				if flag == 2:
					var initial := 75 if choice == 2 else 70 - (2 if choice == 1 else 3)
					_case_add(rows, choice, initial, flags)
	_case_add(rows, 2, 86, [1, 0, 0])
	_case_add(rows, 2, 86, [1, 1, 1])
	return rows.values()


func _case_add(rows: Dictionary, choice: int, initial: int, flags: Array) -> void:
	var row := {"choice": choice, "initial": initial, "flags": flags}
	rows[JSON.stringify(row)] = row


func _validate_matrix_distinctions() -> void:
	_check(_matrix.size() == 72, "face flag matrix coverage changed")
	for choice in [1, 2, 3]:
		for flag in range(3):
			var initial := (75 if choice == 2 else 70 - (2 if choice == 1 else 3)) if flag == 2 else 76
			var columns := []
			for value in [0, 1, 2, 255]:
				var flags := [0, 0, 0]
				flags[flag] = value
				var found := _matrix.filter(func(row): return row.choice == choice and row.initial == initial and row.flags == flags)
				columns.append(found[0].column if found.size() == 1 else -1)
			var ordinary_column := 0 if flag == 2 else 2
			_check(columns == [ordinary_column, 1, ordinary_column, ordinary_column], "choice %d / flag %d no longer discriminates ==1 from 0/2/255" % [choice, FLAGS[flag]])


func _validate_flag_guard() -> void:
	var code: PackedByteArray = _documents["B_PIC.MES"].bytecode
	var guard := Decoder.new().decode_at_structural(code, 0x0568)
	_check(guard.get("ok", false) and guard.get("op", "") == "branch_if_not_true" and guard.get("end_offset", -1) == 0x0597 and _sha256(code.slice(0x0568, 0x0597)) == FLAG_GUARD_SHA256, "combined face guard identity/boundary changed")
	if not guard.get("ok", false):
		return
	var expected := [
		["less_than", ["banked_u16", 0, 210], 31],
		["equal", ["global_u8", 0, 204], 1],
		["logical_and", ["equal", ["global_u8", 0, 207], 1], ["less_than", ["banked_u16", 0, 210], 81]],
		["logical_and", ["equal", ["global_u8", 0, 628], 1], ["less_than", ["banked_u16", 0, 210], 71]],
	]
	var terms := _or_terms(guard.operands[0].value.ast)
	_check(terms == expected and guard.operands[1].value == 0x0626, "combined face guard expression changed: %s" % JSON.stringify(terms))


func _or_terms(ast: Dictionary) -> Array:
	if ast.get("op", "") == "logical_or":
		return _or_terms(ast.get("lhs", {})) + _or_terms(ast.get("rhs", {}))
	return [_expression_signature(ast)]


func _expression_signature(ast: Dictionary) -> Variant:
	match str(ast.get("type", "")):
		"literal":
			return ast.get("value")
		"state_ref":
			var index: Dictionary = ast.get("index", {})
			return [ast.get("storage", ""), ast.get("bank", -1), index.get("value", -1)] if index.get("type", "") == "literal" else []
		"binary":
			return [ast.get("op", ""), _expression_signature(ast.get("lhs", {})), _expression_signature(ast.get("rhs", {}))]
	return []


func _validate_flag_case(row: Dictionary) -> void:
	_events.clear()
	_trace.clear()
	_writes.clear()
	_picture_input.clear()
	_conditions.clear()
	var state := State.new(1)
	for pair in [[4, 6], [7, 413], [12, 100], [19, 1825]]:
		state.write_value("state_u16", pair[0], pair[1])
	state.write_value("banked_u16", 210, row.initial, 0)
	for i in range(3):
		state.write_value("global_u8", FLAGS[i], row.flags[i])
	var before := state.snapshot()
	var result := _walk("EVENTB03.MES", state, 0, row.choice)
	var label := "choice %d / initial %d / flags %s" % [row.choice, row.initial, row.flags]
	_check(result.get("ok", false), "%s reached an unsupported boundary" % label)
	if not result.get("ok", false):
		print("UNSUPPORTED_FACE_FLAG ", JSON.stringify({"case": row, "result": result, "last_trace": _trace[-1] if not _trace.is_empty() else {}, "partial_diff": state.diff(before)}))
		return
	var final_affection: int = row.initial - 5 if row.choice == 2 else row.initial + (2 if row.choice == 1 else 3)
	var force_low: bool = final_affection < 31 or row.flags[0] == 1 or (row.flags[1] == 1 and final_affection < 81) or (row.flags[2] == 1 and final_affection < 71)
	var column := 1 if force_low else (0 if final_affection < 71 else 2)
	var face: Dictionary = FACE_PROFILES[column]
	var root_events := _events.filter(func(event): return event.entry == "EVENTB03.MES")
	var expected_suffix: Array = HIGH_SUFFIX if row.choice == 2 else ROUTES[row.choice].suffix
	_check(root_events.filter(func(event): return event.status == "dialogue_boundary").map(func(event): return event.offset) == PREFIX + expected_suffix, "%s root dialogue order changed" % label)
	var picture_returns := _events.filter(func(event): return event.entry == "B_PIC.MES" and event.status == "script_return")
	var outer := _trace.filter(func(event): return event.entry != "B_PIC.MES")
	if outer.size() != OUTER_TRACES[row.choice][0] or JSON.stringify(outer).sha256_text() != OUTER_TRACES[row.choice][1]:
		print("B03_FACE_OUTER_DIAGNOSTIC choice=%d rows=%d sha=%s" % [row.choice, outer.size(), JSON.stringify(outer).sha256_text()])
	_check(outer.size() == OUTER_TRACES[row.choice][0] and JSON.stringify(outer).sha256_text() == OUTER_TRACES[row.choice][1], "%s complete outer trace changed" % label)
	var outer_events := root_events.map(func(event): return [event.status, event.offset, event.resume, event.get("arguments", {}), event.get("omitted_native_records", -1)])
	if row.flags == [0, 0, 0] and row.initial == 76:
		_baselines[row.choice] = {"trace": outer.duplicate(true), "events": outer_events.duplicate(true)}
	else:
		_check(outer == _baselines[row.choice].trace and outer_events == _baselines[row.choice].events, "%s differs from the independent zero-flag baseline" % label)
	_check(_picture_input == {"flags": row.flags, "affection": final_affection, "state12": 0 if row.choice == 2 else 100, "bank251": 100 if row.choice == 2 else 0}, "%s picture caller values changed" % label)
	_check(_writes.all(func(write): return write.storage in ["global_u8", "global_i32", "state_u16", "banked_u8", "banked_u16", "banked_i32"] and write.bank >= 0 and write.start >= 0 and write.count > 0 and write.mask == (0xFF if write.storage == "state_u16" else -1)), "%s incomplete write schema" % label)
	_check(_writes.filter(func(write): return FLAGS.any(func(index): return _write_touches(write, "global_u8", index))).is_empty(), "%s contains a tested-flag write" % label)
	_check(FLAGS.map(func(index): return state.read_value("global_u8", index)) == row.flags, "%s final input flags changed" % label)
	_check(state.read_value("banked_u16", 210, 0) == final_affection and state.read_value("state_u16", 12) == 100 and state.read_value("banked_u16", 251, 0) == (100 if row.choice == 2 else 0), "%s final numeric values changed" % label)
	var nested_diff: Array = _expected_picture_diff(row.choice, column)
	_check(picture_returns.size() == 1 and picture_returns[0].offset == 0x0759 and picture_returns[0].end == 0x075A and picture_returns[0].trace_sha256 == face.trace and picture_returns[0].nested_diff == nested_diff, "%s complete picture trace/return/diff changed" % label)
	var picture_trace := _trace.filter(func(event): return event.entry == "B_PIC.MES")
	_check(picture_trace.filter(func(event): return event.has("cell_column")).map(func(event): return [event.offset, event.end, event.effect, event.cell_row, event.cell_column]) == [[face.binding, face.active, "ax_presentation_binding", 0, column], [face.active, face.active_end, "ax_selected_cell_state_0_omitted", 0, column]], "%s selected face records changed" % label)
	_check(picture_trace.filter(func(event): return event.has("resource_name")).map(func(event): return [event.offset, str(event.resource_name).to_upper()]) == [[0x00A0, "MAHOKO.WAV"], [0x02E4, "B1.MMO"], [face.mmo, "BAN.MMO"], [face.ax, "B.AX"]], "%s picture media changed" % label)
	var guard_results := _conditions.filter(func(event): return event.entry == "B_PIC.MES" and event.offset in [0x0568, 0x0626, 0x06C2])
	var expected_guards: Array = [[0x0568, 0x0597, 1, "fallthrough"]] if force_low else ([[0x0568, 0x0597, 0, "branch"], [0x0626, 0x0633, 1, "fallthrough"]] if column == 0 else [[0x0568, 0x0597, 0, "branch"], [0x0626, 0x0633, 0, "branch"], [0x06C2, 0x06CF, 1, "fallthrough"]])
	_check(guard_results.map(func(event): return [event.offset, event.end, event.condition, event.effect]) == expected_guards, "%s exact guard evaluation/path changed" % label)
	var expected_diff: Dictionary = _expected_final_diff(100, row.initial, final_affection, column) if row.choice == 2 else _expected_preset_diff(row.choice, row.initial, final_affection, column)
	_check(_diff_values(state.diff(before)) == expected_diff, "%s complete final diff changed" % label)
	var expected_terminal: Array = [0x26F4, 0x2701] if row.choice == 2 else ROUTES[row.choice].terminal
	_check(result.terminal.status == "script_handoff_boundary" and result.terminal.offset == expected_terminal[0] and result.terminal.end == expected_terminal[1] and result.terminal.target == "MACHI.MES", "%s MACHI replacement changed" % label)
	_matrix.append({"choice": row.choice, "initial": row.initial, "flags": row.flags, "output": final_affection, "column": column})


func _walk(entry: String, state: KakyuMesSandboxState, depth: int, choice_result := 2) -> Dictionary:
	if entry == "B_PIC.MES":
		_picture_input = {"flags": FLAGS.map(func(index): return state.read_value("global_u8", index)), "affection": state.read_value("banked_u16", 210, 0), "state12": state.read_value("state_u16", 12), "bank251": state.read_value("banked_u16", 251, 0)}
	return super._walk(entry, state, depth, choice_result)


func _append_trace(entry: String, rows: Array) -> void:
	super._append_trace(entry, rows)
	for row in rows:
		if row.has("condition_value"):
			_conditions.append({"entry": entry, "offset": row.source_offset, "end": row.end_offset, "effect": row.effect, "condition": row.condition_value})
