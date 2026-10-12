extends "res://tools/content_suite/cli/audit_eventb03_affection.gd"

# Original-Core audit only: no Event Player policy, media playback, Python MES
# projection, or original-engine GUI execution is used to produce these traces.
const DefinitionCall := preload("res://content_core/mes_registered_definition_call.gd")
const ROOT_DEFINITIONS := {
	0x295D: {"id": 22, "resume": 0x2962, "body": 0x1109, "end": 0x116E, "call": 0x1163, "call_resume": 0x1168, "body_sha256": "5ce9901c609dd873cccd78bc53c613eea0bf6a4cc71dd335e6152bd1910f39d6", "call_sha256": "8a4df94a8b3863bc7d3cf2677581fae814e5059cf11c0c1e201c53e40d02a620"},
	0x2AE9: {"id": 21, "resume": 0x2AEE, "body": 0x10C4, "end": 0x1102, "call": 0x10F7, "call_resume": 0x10FC, "body_sha256": "bdc0219bdf88995ae3e7cb30c164053a5f62567d6b9af122eec54d45edf5919f", "call_sha256": "1b9783b4a57f92cae3849d16ab60ae6568429b2289485716ce846b6f6f78f950"},
}
const ROOT_STREAMS := {0x2A74: 0x2A7B, 0x2ACE: 0x2AD5, 0x2C15: 0x2C1C, 0x2C74: 0x2C7B, 0x2D4C: 0x2D53, 0x2DA6: 0x2DAD, 0x2E9D: 0x2EA4}
const STREAM_SHORT_SHA256 := "b3c1304f83089f364c2a4bf4e30b322fee80693cd11c8d5f31841a17cb3d80ea"
const STREAM_LONG_SHA256 := "a06617c218350923c519426e47ffdb1691ae8eef45293f714fc2877a58f71679"
const STREAM_FINAL_SHA256 := "57941c875d2fb87d4536204d676ecdf326b1f0bcb4b2751eff18cfa9c953d5da"
const CAMERAS := {
	0x32F9: {"end": 0x3311, "sha256": "9b393103d08fe51f0618e1548b4704e8d8157fdea4dc12fe87267bbaa99d9fbd"},
	0x3316: {"end": 0x332E, "sha256": "1c71a164db8b072a062cfefcc9776a81c9a3685d02372bef53638b8fae729ed3"},
}
const ROUTES := {
	1: {
		"suffix": [0x1336, 0x1374, 0x13C6, 0x1411, 0x1473, 0x157E, 0x15D3, 0x168F, 0x1700, 0x176A, 0x17C1, 0x1843, 0x18A6, 0x1930, 0x196D, 0x19F9, 0x1A48, 0x1B25, 0x1B82],
		"libraries": [[0x1497, 28, 1, 3], [0x14CC, 27, 11, 0], [0x14D8, 25, 11, 33], [0x1512, 21, 11, 0], [0x1539, 32, 11, 2], [0x1549, 28, 0, 2], [0x1A81, 27, 11, 0], [0x1A8D, 25, 11, 33], [0x1AC7, 21, 11, 0]],
		"media": [[0x1639, "B0806.OGG"], [0x1726, "B0807.OGG"], [0x17E7, "B0808.OGG"], [0x18CC, "B0809.OGG"], [0x1993, "B0810.OGG"], [0x1AF0, "KSE0069.WAV"]],
		"affection_write": 0x15F1, "affection_end": 0x1600, "addition": 2, "affection_sha256": "3847eccd37c7064447cde181d1729ab42e832d971396dadf8a62e0721d1e9e98",
		"picture": [0x1615, 0x1622], "terminal": [0x1BB6, 0x1BC3],
		# Core 0.316.0 (2026-09-13): the outer trace is taken over the system-call
		# framing; every boundary, write and media row above is unchanged.
		# Core 0.377.0 (TD-56): the outer trace now carries each command-0x09 row's
		# write fields and the library rows of the arms the real selector picks.
		"outer_rows": 899, "outer_sha256": "c7ff76ac27946e64ede9b6be1a45e3b00320fba9a9350265a2247795f98ff753",
	},
	3: {
		"suffix": [0x2769, 0x27C7, 0x2829, 0x286D, 0x28B5, 0x293F, 0x2B55, 0x2BA9, 0x2CE0, 0x2DF7, 0x2E6F, 0x3041, 0x308A, 0x3104, 0x3163, 0x31DB, 0x3234, 0x3266, 0x32C9, 0x33A0, 0x3418, 0x345D, 0x34DF, 0x3538, 0x35B4, 0x35FB, 0x365F, 0x36B0, 0x380A, 0x3892, 0x38E5, 0x3961, 0x39C6, 0x3A50, 0x3A8D, 0x3B0F, 0x3B54, 0x3BD6, 0x3CB3, 0x3D12],
		"libraries": [[0x2972, 28, 1, 3], [0x2A17, 28, 0, 0], [0x2A4A, 9, 69, 0], [0x2AA4, 9, 68, 0], [0x2BEB, 9, 69, 0], [0x2C4A, 9, 68, 0], [0x2D22, 9, 68, 0], [0x2D7C, 9, 69, 0], [0x2E93, 28, 1, 3], [0x2F1C, 28, 0, 0], [0x36ED, 28, 1, 3], [0x3722, 27, 11, 0], [0x372E, 25, 11, 33], [0x3768, 21, 11, 0], [0x378F, 32, 11, 2], [0x379F, 28, 0, 2], [0x3C0F, 27, 11, 0], [0x3C1B, 25, 11, 33], [0x3C55, 21, 11, 0]],
		"media": [[0x299B, "BLL.MMO"], [0x2B05, "B0815.OGG"], [0x2C92, "B0816.OGG"], [0x2EB0, "B05SS.MMO"], [0x2F4A, "B05SSAN.MMO"], [0x2F62, "B05SS.AX"], [0x2FC4, "H_H_H.WAV"], [0x2FF5, "B0817.OGG"], [0x30B0, "B0818.OGG"], [0x3189, "B0819.OGG"], [0x33C6, "B0820.OGG"], [0x3483, "B0821.OGG"], [0x3568, "B0822.OGG"], [0x3621, "B0823.OGG"], [0x3830, "B0824.OGG"], [0x390B, "B0825.OGG"], [0x39EC, "B0826.OGG"], [0x3AB3, "B0827.OGG"], [0x3B7A, "B0828.OGG"], [0x3C7E, "KSE0069.WAV"]],
		"affection_write": 0x36CE, "affection_end": 0x36DD, "addition": 3, "affection_sha256": "0736985e0a02bedc7864bb1b01f946331e16e1af33c5ae574d6ff2b12b8da0f8",
		"picture": [0x37B9, 0x37C6], "terminal": [0x3D46, 0x3D53],
		"outer_rows": 1446, "outer_sha256": "3e626e47d8c1ae7008f638b910c5d7031b9a21906739cb059384e0c133046a34",
	},
}

var _writes: Array[Dictionary] = []
var _baselines := {}


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
	_check(before_hashes["mes.arc"] == MES_SHA256, "original mes.arc identity changed")
	if _failures.is_empty():
		_check(_reader.open(source_root.path_join("mes.arc")), "original archive unavailable")
	if _failures.is_empty():
		_load_documents()
	if _failures.is_empty():
		_validate_source_records()
		_validate_affection_records()
		_validate_additional_records()
		_validate_extra_boundary_rejections()
	if _failures.is_empty():
		for selection in [1, 3]:
			for profile in [[0, 0], [100, 0], [100, 36], [100, 76]]:
				_validate_preset_case(selection, profile[0], profile[1])
	_reader.close()
	for archive in before_hashes:
		_check(FileAccess.get_sha256(source_root.path_join(archive)) == before_hashes[archive], "%s changed during audit" % archive)
	if not _failures.is_empty():
		push_error("EVENTB03 preset choices audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: EVENTB03 preset choices source audit: %d checks; two zero-entry baselines and six initial-100 result-1/3 routes; exact dialogue, LIB/DEF/native/camera metadata, unchanged outer traces, face bindings, complete final diffs and no state12/bank251 writes; six archives unchanged. Core %s / %s. Not native GUI/cadence or host eligibility." % [_checks, CoreVersion.CORE_VERSION, CoreVersion.MES_INSTRUCTION_SCHEMA])
	quit(0)


func _validate_additional_records() -> void:
	var code: PackedByteArray = _documents["EVENTB03.MES"].bytecode
	for selection in ROUTES:
		var route: Dictionary = ROUTES[selection]
		var write := Decoder.new().decode_at_structural(code, route.affection_write)
		_check(_sha256(code.slice(route.affection_write, route.affection_end)) == route.affection_sha256, "result %d affection envelope identity changed" % selection)
		_check(write.get("ok", false) and write.get("op", "") == "banked_u16_write_run" and write.get("end_offset", -1) == route.affection_end, "result %d affection write boundary changed" % selection)
		if write.get("ok", false):
			_check(write.operands[0].value.ast.get("value", -1) == 210 and write.operands[1].value == 0 and write.operands[2].pairs.size() == 1 and _affection_compare(write.operands[2].pairs[0].expression.ast, "add", route.addition), "result %d affection addition changed" % selection)
		var picture := Decoder.new().decode_at_structural(code, route.picture[0])
		_check(picture.get("ok", false) and picture.get("op", "") == "script_dispatch" and picture.get("end_offset", -1) == route.picture[1], "result %d picture boundary changed" % selection)
		_check(_sha256(code.slice(route.terminal[0], route.terminal[1])) == TERMINAL_SHA256, "result %d terminal envelope changed" % selection)
	for offset in ROOT_STREAMS:
		_check(_stream_matches(offset), "native stream envelope changed at 0x%X" % offset)
	for offset in ROOT_DEFINITIONS:
		_check(_definition_matches(offset), "registered DEF identity changed at 0x%X" % offset)
	for offset in CAMERAS:
		var expected: Dictionary = CAMERAS[offset]
		var decoded := Decoder.new().decode_at_structural(code, offset)
		_check(_sha256(code.slice(offset, expected.end)) == expected.sha256 and decoded.get("ok", false) and decoded.get("end_offset", -1) == expected.end, "camera envelope changed at 0x%X" % offset)


func _validate_preset_case(selection: int, initial_state12: int, initial_affection: int) -> void:
	_events.clear()
	_trace.clear()
	_writes.clear()
	var route: Dictionary = ROUTES[selection]
	var state := State.new(1)
	for pair in [[4, 6], [7, 413], [12, initial_state12], [19, 1825]]:
		state.write_value("state_u16", pair[0], pair[1])
	state.write_value("banked_u16", 210, initial_affection, 0)
	var before := state.snapshot()
	var result := _walk("EVENTB03.MES", state, 0, selection)
	var label := "result %d / state12 %d / affection %d" % [selection, initial_state12, initial_affection]
	_check(result.get("ok", false), "%s stopped at an unexpected boundary: %s" % [label, result])
	if not result.get("ok", false):
		return
	var final_affection := initial_affection + int(route.addition)
	var column := 1 if final_affection < 31 else (0 if final_affection < 71 else 2)
	var face: Dictionary = FACE_PROFILES[column]
	var root_events := _events.filter(func(row): return row.entry == "EVENTB03.MES")
	var suffix_trace := _trace.filter(func(row): return row.entry == "EVENTB03.MES" and row.offset >= 0x12D7)
	_check(root_events.filter(func(row): return row.status == "dialogue_boundary").map(func(row): return row.offset) == PREFIX + route.suffix, "%s dialogue order changed" % label)
	var libraries := root_events.filter(func(row): return row.status == "shared_routine_boundary")
	var expected_libraries: Array = [[0x00FC, 28, 1, 3], [0x0235, 28, 0, 0], [0x08DF, 21, 46635, 0]] + route.libraries
	var actual_libraries := libraries.map(func(row): return [row.offset, row.routine, row.arguments.get(1, -1), row.omitted_native_records])
	if actual_libraries != expected_libraries:
		print("B03_PRESET_LIBRARIES_DIAGNOSTIC %s %s" % [label, JSON.stringify(actual_libraries)])
	_check(actual_libraries == expected_libraries, "%s original shared call sequence changed" % label)
	_check(libraries.filter(func(row): return row.routine == 9).all(func(row): return row.arguments == {1: row.arguments.get(1, -1), 2: 0}), "%s routine9 extra arguments changed" % label)
	_check(suffix_trace.filter(func(row): return row.has("resource_name")).map(func(row): return [row.offset, str(row.resource_name).to_upper()]) == route.media, "%s voice/MMO/AX/named-effect order changed" % label)
	var affection_writes := _writes.filter(func(row): return _write_touches(row, "banked_u16", 210))
	_check(_writes.all(func(row): return row.storage in ["global_u8", "global_i32", "state_u16", "banked_u8", "banked_u16", "banked_i32"] and row.bank >= 0 and row.start >= 0 and row.count > 0 and row.mask == (0xFF if row.storage == "state_u16" else -1)), "%s incomplete write metadata" % label)
	_check(affection_writes.size() == 1 and affection_writes[0].entry == "EVENTB03.MES" and affection_writes[0].offset == route.affection_write and affection_writes[0].end == route.affection_end and affection_writes[0].count == 1, "%s affection write order changed" % label)
	_check(_writes.filter(func(row): return _write_touches(row, "state_u16", 12) or _write_touches(row, "banked_u16", 251)).is_empty(), "%s introduced a temporary/restored state12 or bank251 write" % label)
	_check(root_events.all(func(row): return row.state12 == initial_state12 and row.banked251 == 0), "%s state12/bank251 changed at a root boundary" % label)
	_check(state.read_value("banked_u16", 210, 0) == final_affection and state.read_value("state_u16", 12) == initial_state12 and state.read_value("banked_u16", 251, 0) == 0, "%s final numeric values changed" % label)
	var pictures := root_events.filter(func(row): return row.status == "script_dispatch_boundary")
	_check(pictures.size() == 1 and pictures[0].offset == route.picture[0] and pictures[0].resume == route.picture[1], "%s picture caller changed" % label)
	var picture_events := _events.filter(func(row): return row.entry == "B_PIC.MES")
	var picture_libraries := picture_events.filter(func(row): return row.status == "shared_routine_boundary")
	_check(picture_libraries.size() == 1 and picture_libraries[0].offset == 0x035B and picture_libraries[0].resume == 0x0360 and picture_libraries[0].routine == 22 and picture_libraries[0].arguments.get(1, -1) == 14, "%s picture shared call changed" % label)
	var returns := picture_events.filter(func(row): return row.status == "script_return")
	var nested_diff: Array = _expected_picture_diff(selection, column)
	if returns.size() == 1 and returns[0].nested_diff != nested_diff:
		print("B03_PRESET_PICTURE_DIAGNOSTIC %s diff=%s" % [label, JSON.stringify(returns[0].nested_diff)])
	_check(returns.size() == 1 and returns[0].offset == 0x0759 and returns[0].end == 0x075A and returns[0].trace_sha256 == face.trace and returns[0].nested_diff == nested_diff, "%s picture trace/return/diff changed" % label)
	var picture_trace := _trace.filter(func(row): return row.entry == "B_PIC.MES")
	_check(picture_trace.filter(func(row): return row.has("cell_column")).map(func(row): return [row.offset, row.end, row.effect, row.cell_row, row.cell_column]) == [[face.binding, face.active, "ax_presentation_binding", 0, column], [face.active, face.active_end, "ax_selected_cell_state_0_omitted", 0, column]], "%s face binding/activation changed" % label)
	_check(picture_trace.filter(func(row): return row.has("resource_name")).map(func(row): return [row.offset, str(row.resource_name).to_upper()]) == [[0x00A0, "MAHOKO.WAV"], [0x02E4, "B1.MMO"], [face.mmo, "BAN.MMO"], [face.ax, "B.AX"]], "%s picture media changed" % label)
	var native_events := root_events.filter(func(row): return row.status == "native_presentation_boundary")
	var definition_events := root_events.filter(func(row): return row.status == "definition_invoke_boundary")
	_check(native_events.is_empty(), "%s stopped at a native presentation" % label)
	var omitted_calls := suffix_trace.filter(func(row): return row.effect == "system_call_omitted" and ROOT_STREAMS.has(row.offset))
	_check(omitted_calls.map(func(row): return [row.offset, row.end]) == (ROOT_STREAMS.keys().map(func(offset): return [offset, ROOT_STREAMS[offset]]) if selection == 3 else []), "%s omitted root stream call order changed" % label)
	_check(definition_events.map(func(row): return [row.offset, row.resume]) == ([[0x295D, 0x2962], [0x2AE9, 0x2AEE]] if selection == 3 else []), "%s root DEF order changed" % label)
	var camera_trace := suffix_trace.filter(func(row): return CAMERAS.has(row.offset))
	_check(camera_trace.map(func(row): return [row.offset, row.end, row.effect]) == ([[0x32F9, 0x3311, "native_record_effects_omitted"], [0x3316, 0x332E, "native_record_effects_omitted"]] if selection == 3 else []), "%s camera intervals changed" % label)
	_check(_trace.filter(func(row): return row.entry == "DEF_MAIN.MES" and row.effect == "script_return").map(func(row): return row.offset) == ([0x116D, 0x1101] if selection == 3 else []), "%s DEF return order changed" % label)
	var outer_trace := _trace.filter(func(row): return row.entry != "B_PIC.MES")
	var signature := JSON.stringify(outer_trace).sha256_text()
	if outer_trace.size() != route.outer_rows or signature != route.outer_sha256:
		print("B03_PRESET_OUTER_DIAGNOSTIC %s rows=%d sha=%s" % [label, outer_trace.size(), signature])
	_check(outer_trace.size() == route.outer_rows and signature == route.outer_sha256, "%s complete outer trace fingerprint changed" % label)
	var outer_events := root_events.map(func(row): return [row.status, row.offset, row.resume, row.get("arguments", {}), row.get("omitted_native_records", -1)])
	if initial_state12 == 0:
		_baselines[selection] = {"trace": outer_trace.duplicate(true), "events": outer_events.duplicate(true)}
	else:
		_check(outer_trace == _baselines[selection].trace and outer_events == _baselines[selection].events, "%s differs from the independently executed zero-state baseline" % label)
	var terminal: Dictionary = result.terminal
	_check(terminal.status == "script_handoff_boundary" and terminal.offset == route.terminal[0] and terminal.end == route.terminal[1] and terminal.target == "MACHI.MES", "%s root replacement changed" % label)
	_check(_diff_values(state.diff(before)) == _expected_preset_diff(selection, initial_affection, final_affection, column), "%s complete final diff changed" % label)
	print("PRESET_CHOICE ", JSON.stringify({"result": selection, "initial_state12": initial_state12, "initial_affection": initial_affection, "final_affection": final_affection, "face_column": column, "suffix_dialogues": route.suffix.size(), "root_shared_calls": libraries.size(), "outer_trace_sha256": signature, "picture_trace_sha256": face.trace, "terminal_offset": terminal.offset}))


func _expected_preset_diff(selection: int, initial_affection: int, final_affection: int, column: int) -> Dictionary:
	var expected := {"banked_u16/0/1": [0, 7], "banked_u16/0/210": [initial_affection, final_affection], "state_u16/0/21": [0, selection]}
	for index in [206, 286, 3688, 5306, 626, 631, 632] + ([3002, 5307, 638] if selection == 3 else []):
		expected["global_u8/0/%d" % index] = [0, 1]
	expected["global_u8/0/627"] = [0, 1 if selection == 1 else 2]
	expected["global_i32/0/1"] = [0, FINAL_ARGUMENT[selection]]
	if column != 0:
		expected["global_u8/0/3005"] = [0, column]
	return expected


func _append_trace(entry: String, rows: Array) -> void:
	super._append_trace(entry, rows)
	for row in rows:
		if row.has("write_storage"):
			_writes.append({"entry": entry, "offset": int(row.source_offset), "end": int(row.end_offset), "storage": str(row.write_storage), "bank": int(row.get("write_bank", -1)), "start": int(row.get("write_start", -1)), "count": int(row.get("write_count", -1)), "mask": int(row.get("write_index_mask", -1))})


func _write_touches(row: Dictionary, storage: String, index: int) -> bool:
	if row.storage != storage or row.bank != 0:
		return false
	for step in range(row.count):
		var destination := int(row.start) + step
		if row.mask >= 0:
			destination &= int(row.mask)
		if destination == index:
			return true
	return false


func _stream_matches(offset: int) -> bool:
	if not ROOT_STREAMS.has(offset):
		return false
	var code: PackedByteArray = _documents["EVENTB03.MES"].bytecode
	var decoded := Decoder.new().decode_at_structural(code, offset)
	var expected_hash := STREAM_FINAL_SHA256 if offset == 0x2E9D else (STREAM_LONG_SHA256 if offset in [0x2ACE, 0x2C74] else STREAM_SHORT_SHA256)
	# Core 0.316.0 (2026-09-13): each root stream is one system call,
	# System.function[12](parameter), that the runtime omits and runs past; the
	# separator framing stopped on it as a "character stream presentation".
	return _sha256(code.slice(offset, ROOT_STREAMS[offset])) == expected_hash and decoded.get("ok", false) and decoded.get("op", "") == "system_call" and int(decoded.get("system_function", -1)) == 12 and decoded.get("end_offset", -1) == ROOT_STREAMS[offset]


func _definition_matches(offset: int) -> bool:
	if not ROOT_DEFINITIONS.has(offset):
		return false
	var expected: Dictionary = ROOT_DEFINITIONS[offset]
	var definition: Dictionary = _definitions.get(expected.id, {})
	return definition.get("body_offset", -1) == expected.body and definition.get("end_offset", -1) == expected.end and definition.get("source_entry", "") == "DEF_MAIN.MES" and _sha256(_documents["DEF_MAIN.MES"].bytecode.slice(expected.body, expected.end)) == expected.body_sha256 and _sha256(_documents["EVENTB03.MES"].bytecode.slice(offset, expected.resume)) == expected.call_sha256


func _validate_extra_boundary_rejections() -> void:
	var state := State.new(1)
	var before := state.snapshot()
	var context := {"argument_slots": {}, "persistent_expression_stack": []}
	# Core 0.316.0 (2026-09-13): the runtime no longer stops at the root
	# streams, so a native presentation boundary can only be a foreign result.
	var stream := {"status": "native_presentation_boundary", "offset": 0x2A74, "trace": [{}]}
	_check(not _walk_additional_boundary("EVENTB03.MES", stream, state, context, 3).get("ok", false), "native boundary accepted")
	var definition := {"status": "definition_invoke_boundary", "offset": 0x295D, "resume_offset": 0x2962, "trace": [{"definition_id": 21}]}
	_check(not _walk_additional_boundary("EVENTB03.MES", definition, state, context, 3).get("ok", false), "cross-DEF identity accepted")
	_check(state.snapshot() == before, "rejected extra boundary changed sandbox state")


func _walk_additional_boundary(entry: String, result: Dictionary, state: KakyuMesSandboxState, context: Dictionary, selection: int) -> Dictionary:
	if entry != "EVENTB03.MES" or selection != 3:
		return {"ok": false, "status": result.status, "offset": result.offset}
	var terminal: Dictionary = result.trace[-1]
	var offset := int(result.offset)
	if str(result.status) != "definition_invoke_boundary" or not _definition_matches(offset):
		return {"ok": false, "status": result.status, "offset": offset}
	var expected: Dictionary = ROOT_DEFINITIONS[offset]
	var definition: Dictionary = _definitions.get(expected.id, {})
	if int(result.get("resume_offset", -1)) != expected.resume or int(terminal.get("definition_id", -1)) != expected.id or definition.get("body_offset", -1) != expected.body or definition.get("end_offset", -1) != expected.end or definition.get("source_entry", "") != "DEF_MAIN.MES":
		return {"ok": false, "status": "definition_identity", "offset": offset}
	var cursor := int(expected.body)
	var arguments: Dictionary = context.argument_slots.duplicate(true)
	var stack: Array = context.persistent_expression_stack.duplicate()
	for segment in range(2):
		var continuation := definition.duplicate(false)
		continuation["body_offset"] = cursor
		var output := DefinitionCall.new().run(expected.id, continuation, state, {"argument_slots": arguments, "persistent_expression_stack": stack, "native_stream_policy": "skip_bounded", "native_record_policy": "omit_bounded"})
		_append_trace("DEF_MAIN.MES", output.get("trace", []))
		arguments = output.get("argument_slots", {}).duplicate(true)
		stack = output.get("persistent_expression_stack", []).duplicate()
		if segment == 1:
			if not output.get("ok", false) or str(output.status) != "definition_return" or int(output.get("offset", -1)) != expected.end - 1:
				return {"ok": false, "status": "definition_return", "offset": output.get("offset", -1)}
			return {"ok": true, "resume_offset": expected.resume, "argument_slots": arguments, "persistent_expression_stack": stack}
		if str(output.status) != "definition_shared_routine_boundary" or int(output.get("offset", -1)) != expected.call or int(output.get("resume_offset", -1)) != expected.call_resume or output.trace[-1].get("routine_id", -1) != 3:
			return {"ok": false, "status": "definition_library", "offset": output.get("offset", -1)}
		var library := LibraryRunner.new().run(_documents["LIBLARY.LIB"].bytecode, _library_index, 3, state, {"argument_slots": arguments, "persistent_expression_stack": stack, "registered_definitions": _definitions})
		if not library.get("ok", false) or str(library.status) != "library_return" or library.trace.size() != 2 or not library.messages.is_empty():
			return {"ok": false, "status": "definition_library_return"}
		_append_trace("LIBLARY.LIB", library.trace)
		arguments = library.get("argument_slots", {}).duplicate(true)
		stack = library.get("persistent_expression_stack", []).duplicate()
		cursor = int(expected.call_resume)
	return {"ok": false}
