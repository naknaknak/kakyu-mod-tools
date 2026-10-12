extends SceneTree

# Read-only source audit: no Event Player, audio, native effects, or GUI replay.
const ArcReader := preload("res://content_core/arc_reader.gd")
const MesContainer := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const Runner := preload("res://content_core/mes_event_runner.gd")
const LibraryIndex := preload("res://content_core/mes_library_index.gd")
const LibraryRunner := preload("res://content_core/mes_library_runner.gd")
const StartupContext := preload("res://content_core/mes_startup_context.gd")
const ChoiceContract := preload("res://content_core/mes_routine40_choice_contract.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const CoreVersion := preload("res://content_core/content_core_version.gd")

const MES_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const ENTRY_HASHES := {
	"EVENTB03.MES": "558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230",
	"LIBLARY.LIB": "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d",
	"B_PIC.MES": "d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada",
	"DEF_MAIN.MES": "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0",
}
# Core 0.316.0 (2026-09-13): the B_PIC route is unchanged - return 0x0759, media,
# binding and state diff - but its trace signature is taken over the system-call
# framing.
const PICTURE_TRACE_SHA256 := "166f2b6c123dbd1110e73b473de819064e787a5a0bbbd304b389b0d710dd45df"
# Core 0.377.0 (TD-56): command 0x09 writes global_i32, the storage token 0xF6 reads,
# so the routes' argument assignments are sandbox changes. Per EVENTB03 choice result:
# `PICTURE_ARGUMENT_BEFORE` is global_i32[1] when the route enters B_PIC (the last
# message record id the caller assigned; B_PIC leaves 0, and result 3 already holds
# 0, so it reports no row) and `FINAL_ARGUMENT` is
# its value at the root's handoff to MACHI (the last assignment of the route).
# These are the values the unchanged source bytes produce, not new route facts.
const PICTURE_ARGUMENT_BEFORE := {1: 46665, 2: 46691, 3: 0}
const FINAL_ARGUMENT := {1: 46677, 2: 46701, 3: 46741}
const TERMINAL_SHA256 := "496ee6fc5e929a0d78f596b742cf256b0651842fc13c717c182cd217879ac047"
const RESTORE_SHA256 := "9f02426ea66178a7f6681a748cd2940a32a43790c595d79db12b5006bc219f4a"
const PREFIX := [0x039C, 0x03E8, 0x0474, 0x04DC, 0x0536, 0x0584, 0x0614, 0x0690, 0x06EE, 0x0764, 0x07A6, 0x07F4, 0x083F, 0x09A2, 0x0CF3, 0x0D52, 0x0DB1, 0x0E0D, 0x0E80, 0x0EEA, 0x0F40, 0x0FA9, 0x1003, 0x1053, 0x10B1, 0x111F, 0x117C, 0x11DE]
const LOW_SUFFIX := [0x1C1B, 0x1C77, 0x1E68, 0x1EDE, 0x1F2B, 0x1FB2, 0x200C, 0x206A, 0x21B0, 0x220F, 0x22B2, 0x2305, 0x237F, 0x2400, 0x2472, 0x24B1, 0x2537, 0x2586, 0x2663, 0x26C0]
const HIGH_SUFFIX := [0x1C1B, 0x1C77, 0x1CD7, 0x1D51, 0x1DAB, 0x1E0F, 0x21B0, 0x220F, 0x22B2, 0x2305, 0x237F, 0x2400, 0x2472, 0x24B1, 0x2537, 0x2586, 0x2663, 0x26C0]
const SUFFIX_LIBRARIES := [[0x20C5, 28], [0x20FA, 27], [0x2106, 25], [0x2140, 21], [0x2167, 32], [0x2177, 28], [0x25BF, 27], [0x25CB, 25], [0x2605, 21]]

var _reader := ArcReader.new()
var _documents := {}
var _library_index := {}
var _definitions := {}
var _events: Array[Dictionary] = []
var _trace: Array[Dictionary] = []
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_audit")


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
	if _failures.is_empty():
		for initial_value in [0, 1, 99, 100, 101, 65535]:
			_validate_case(initial_value)
	_reader.close()
	for archive in before_hashes:
		_check(FileAccess.get_sha256(source_root.path_join(archive)) == before_hashes[archive], "%s changed during audit" % archive)
	if not _failures.is_empty():
		push_error("EVENTB03 state12 audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: EVENTB03 result 2 state12 source audit: %d checks; six inputs, exact 20/18-dialogue branches, temporary writes and restoration, shared LIB/B_PIC/media/terminal; six archives unchanged. Core %s / %s. Not a GUI/native-cadence audit or six-value product authorization." % [_checks, CoreVersion.CORE_VERSION, CoreVersion.MES_INSTRUCTION_SCHEMA])
	quit(0)


func _load_documents() -> void:
	for entry in ["01M.MES", "EVENTB03.MES", "LIBLARY.LIB", "B_PIC.MES", "DEF_MAIN.MES"]:
		var document := MesContainer.new().parse(_reader.read_entry(entry), {
			"archive": "mes.arc", "entry": entry, "resolved_source": "original_arc",
		})
		_check(document.get("ok", false), "%s could not be parsed" % entry)
		if ENTRY_HASHES.has(entry):
			_check(document.get("entry_sha256", "") == ENTRY_HASHES[entry], "%s entry identity changed" % entry)
		_documents[entry] = document
	if not _failures.is_empty():
		return
	_library_index = LibraryIndex.new().build(_documents["LIBLARY.LIB"].bytecode, _documents["LIBLARY.LIB"].header.code_size)
	_check(_library_index.get("ok", false), "shared-library index changed")
	var startup := StartupContext.new().build(_documents["DEF_MAIN.MES"])
	_check(startup.get("ok", false) and startup.get("selector_order", []) == [18, 81, 26, 11, 12, 14, 15, 17, 21, 22, 23, 20, 80, 99], "startup DEF registry changed")
	_definitions = startup.get("registered_definitions", {})


func _validate_source_records() -> void:
	var caller := Decoder.new().decode_at_structural(_documents["01M.MES"].bytecode, 0x788F)
	_check(caller.get("op", "") == "script_handoff_marker" and caller.get("end_offset", -1) == 0x789F and str(caller.get("script_target", "")).to_upper() == "EVENTB03.MES", "01M host activation changed")
	var code: PackedByteArray = _documents["EVENTB03.MES"].bytecode
	var guard := Decoder.new().decode_at_structural(code, 0x1C90)
	_check(guard.get("ok", false) and guard.get("end_offset", -1) == 0x1C9A, "state12 guard boundary changed")
	if not guard.get("ok", false):
		return
	var ast: Dictionary = guard.operands[0].value.ast
	_check(ast.get("op", "") == "greater_than" and _is_state_ref(ast.get("lhs", {}), "state_u16", 12) and ast.get("rhs", {}).get("value", -1) == 99 and guard.operands[1].value == 0x1E2D, "state12 unsigned threshold expression changed")
	for record in [[0x1CF5, 0x1CFF, "banked_u16_write_run"], [0x1D04, 0x1D0C, "state_u16_write_run"], [0x1F49, 0x1F53, "banked_u16_write_run"], [0x1F58, 0x1F5D, "state_u16_write_run"], [0x239D, 0x23A6, "state_u16_write_run"], [0x2238, 0x2245, "script_dispatch"], [0x26F4, 0x2701, "script_handoff_marker"]]:
		var decoded := Decoder.new().decode_at_structural(code, record[0])
		_check(decoded.get("ok", false) and decoded.get("end_offset", -1) == record[1] and decoded.get("op", "") == record[2], "source boundary changed at 0x%X" % record[0])
	var restore := Decoder.new().decode_at_structural(code, 0x239D)
	_check(_sha256(code.slice(0x239D, 0x23A6)) == RESTORE_SHA256 and restore.operands[0].value == 12 and _is_state_ref(restore.operands[1].pairs[0].expression.ast, "banked_u16", 251), "restoration expression changed")
	_check(_sha256(code.slice(0x26F4, 0x2701)) == TERMINAL_SHA256, "MACHI root-replacement envelope changed")


func _validate_case(initial_value: int) -> void:
	_events.clear()
	_trace.clear()
	var state := State.new(1)
	for pair in [[4, 6], [7, 413], [12, initial_value], [19, 1825]]:
		state.write_value("state_u16", pair[0], pair[1])
	var result := _walk("EVENTB03.MES", state, 0)
	_check(result.get("ok", false), "input %d stopped at an unexpected boundary" % initial_value)
	if not result.get("ok", false):
		return
	var root_events := _events.filter(func(row): return row.entry == "EVENTB03.MES")
	var prefix := root_events.filter(func(row): return row.status == "dialogue_boundary" and row.offset < 0x12D7).map(func(row): return row.offset)
	var suffix := root_events.filter(func(row): return row.status == "dialogue_boundary" and row.offset >= 0x12D7).map(func(row): return row.offset)
	var libraries := root_events.filter(func(row): return row.status == "shared_routine_boundary" and row.offset >= 0x12D7)
	var pictures := root_events.filter(func(row): return row.status == "script_dispatch_boundary")
	var picture_returns := _events.filter(func(row): return row.entry == "B_PIC.MES" and row.status == "script_return")
	var suffix_trace := _trace.filter(func(row): return row.entry == "EVENTB03.MES" and row.offset >= 0x12D7)
	var field_writes := suffix_trace.filter(func(row): return row.get("write_storage", "") == "state_u16" and row.get("write_start", -1) == 12 or row.get("write_storage", "") == "banked_u16" and row.get("write_start", -1) == 251)
	var temporary := maxi(initial_value - 100, 0)
	_check(prefix == PREFIX, "input %d prefix changed" % initial_value)
	_check(suffix == (LOW_SUFFIX if initial_value < 100 else HIGH_SUFFIX), "input %d suffix changed" % initial_value)
	_check(libraries.map(func(row): return [row.offset, row.routine]) == SUFFIX_LIBRARIES, "input %d shared calls changed" % initial_value)
	_check(libraries.map(func(row): return row.arguments.get(1, -1)) == [1, 11, 11, 11, 11, 0, 11, 11, 11], "input %d shared arguments changed" % initial_value)
	for library in libraries:
		if library.routine == 25:
			_check(library.omitted_native_records == 33, "input %d shared DEF26 omission count changed" % initial_value)
	_check(field_writes.map(func(row): return row.offset) == ([0x1F49, 0x1F58, 0x239D] if initial_value < 100 else [0x1CF5, 0x1D04, 0x239D]), "input %d assignment sequence changed" % initial_value)
	var temporary_boundary := root_events.filter(func(row): return row.offset == (0x1FB2 if initial_value < 100 else 0x1D51))
	_check(temporary_boundary.size() == 1 and temporary_boundary[0].state12 == temporary and temporary_boundary[0].banked251 == initial_value, "input %d temporary state changed" % initial_value)
	var restored_boundary := root_events.filter(func(row): return row.offset == 0x2400)
	var before_restore := root_events.filter(func(row): return row.offset == 0x237F)
	_check(before_restore.size() == 1 and before_restore[0].state12 == temporary and before_restore[0].banked251 == initial_value, "input %d restored its value before the source command" % initial_value)
	_check(restored_boundary.size() == 1 and restored_boundary[0].state12 == initial_value and restored_boundary[0].banked251 == initial_value, "input %d restored state changed" % initial_value)
	_check(pictures.size() == 1 and pictures[0].offset == 0x2238 and pictures[0].resume == 0x2245 and pictures[0].state12 == temporary and pictures[0].banked251 == initial_value, "input %d B_PIC caller changed" % initial_value)
	if picture_returns.size() == 1:
		print("B03_STATE12_PICTURE_DIAGNOSTIC input=%d return=0x%X trace=%s diff=%s" % [initial_value, int(picture_returns[0].offset), str(picture_returns[0].trace_sha256), JSON.stringify(picture_returns[0].nested_diff)])
	_check(picture_returns.size() == 1 and picture_returns[0].offset == 0x0759 and picture_returns[0].trace_sha256 == PICTURE_TRACE_SHA256 and picture_returns[0].nested_diff == _expected_picture_diff(2, 1), "input %d B_PIC trace/state changed" % initial_value)
	_check(suffix_trace.filter(func(row): return row.has("resource_name")).map(func(row): return [row.offset, str(row.resource_name).to_upper()]) == [[0x225C, "B0811.OGG"], [0x232B, "B0812.OGG"], [0x2426, "B0813.OGG"], [0x24D7, "B0814.OGG"], [0x262E, "KSE0069.WAV"]], "input %d voice/effect resources changed" % initial_value)
	_check(suffix_trace.filter(func(row): return "omitted" in row.effect).map(func(row): return [row.offset, row.end, row.effect]) == [[0x20DF, 0x20E6, "ax_cells_mark_active_omitted"], [0x20E6, 0x20ED, "ax_cells_activate_wait_omitted"], [0x25A4, 0x25AB, "ax_cells_mark_active_omitted"], [0x25AB, 0x25B2, "ax_cells_activate_wait_omitted"]], "input %d root omissions changed" % initial_value)
	_check(suffix_trace.filter(func(row): return row.effect == "effect_request" or row.has("surface_mode")).is_empty(), "input %d introduced a routine9 effect or camera" % initial_value)
	var terminal: Dictionary = result.terminal
	_check(terminal.status == "script_handoff_boundary" and terminal.offset == 0x26F4 and terminal.end == 0x2701 and terminal.target == "MACHI.MES", "input %d terminal changed" % initial_value)
	_check(state.read_value("state_u16", 12) == initial_value and state.read_value("banked_u16", 251, 0) == initial_value and state.read_value("banked_u16", 210, 0) == 0 and state.read_value("state_u16", 21) == 2 and state.read_value("global_u8", 627) == 2 and state.read_value("global_u8", 286) == 1, "input %d final state changed" % initial_value)
	print("STATE12 ", JSON.stringify({"initial": initial_value, "temporary": temporary, "restored": state.read_value("state_u16", 12), "banked251": state.read_value("banked_u16", 251, 0), "prefix_dialogues": prefix.size(), "suffix_dialogues": suffix.size(), "libraries": libraries.size(), "picture_trace_sha256": picture_returns[0].trace_sha256 if not picture_returns.is_empty() else "", "terminal_offset": terminal.offset}))


## B_PIC's own state change for a choice result: the argument cell it overwrites
## (TD-56) and, for a non-zero face column, the column flag.
func _expected_picture_diff(selection: int, column: int) -> Array:
	var rows: Array = []
	if int(PICTURE_ARGUMENT_BEFORE[selection]) != 0:
		rows.append({"storage": "global_i32", "bank": 0, "index": 1, "before": PICTURE_ARGUMENT_BEFORE[selection], "after": 0})
	if column != 0:
		rows.append({"storage": "global_u8", "bank": 0, "index": 3005, "before": 0, "after": column})
	return rows


func _walk(entry: String, state: KakyuMesSandboxState, depth: int, choice_result := 2) -> Dictionary:
	if depth > 1:
		return {"ok": false}
	var document: Dictionary = _documents[entry]
	var cursor := 0
	var trace_start := _trace.size()
	var before := state.snapshot()
	var context := {"native_record_policy": "omit_bounded", "address_table_offsets": document.header.entry_offsets.duplicate(), "protagonist_name": "Audit"}
	for _segment in range(256):
		var result := Runner.new().run(document.bytecode, cursor, state, document.header.code_size, 10000, context)
		_append_trace(entry, result.get("trace", []))
		var terminal: Dictionary = result.trace[-1] if not result.trace.is_empty() else {}
		context["argument_slots"] = result.get("argument_slots", {}).duplicate(true)
		context["persistent_expression_stack"] = result.get("persistent_expression_stack", []).duplicate()
		var event := {"entry": entry, "status": str(result.status), "offset": int(result.offset), "resume": int(result.get("resume_offset", -1)), "state12": state.read_value("state_u16", 12), "banked251": state.read_value("banked_u16", 251, 0)}
		match event.status:
			"shared_routine_boundary":
				var routine := int(terminal.get("routine_id", -1))
				var library_context := {"argument_slots": context.argument_slots.duplicate(true), "persistent_expression_stack": context.persistent_expression_stack.duplicate(), "registered_definitions": _definitions}
				var library_result := LibraryRunner.new().run(_documents["LIBLARY.LIB"].bytecode, _library_index, routine, state, library_context)
				if not library_result.get("ok", false) or str(library_result.get("status", "")) != "library_return" or not library_result.get("messages", []).is_empty():
					return {"ok": false}
				_append_trace("LIBLARY.LIB", library_result.trace)
				event["routine"] = routine
				event["arguments"] = context.argument_slots.duplicate(true)
				event["omitted_native_records"] = int(library_result.get("omitted_native_record_count", -1))
				context["argument_slots"] = library_result.get("argument_slots", {}).duplicate(true)
				context["persistent_expression_stack"] = library_result.get("persistent_expression_stack", []).duplicate()
				cursor = event.resume
			"dialogue_boundary":
				cursor = event.resume
			"def_selection_boundary":
				var contract := ChoiceContract.new().build(document.bytecode, document.header.code_size, result, {"entry": entry, "entry_sha256": document.entry_sha256, "resolved_source": "original_arc", "archive": "mes.arc"})
				if entry != "EVENTB03.MES" or event.offset != 0x12D2 or not contract.get("ok", false) or contract.get("definition_count", -1) != 3 or contract.get("result_index", -1) != 21:
					return {"ok": false}
				if choice_result not in [1, 2, 3]:
					return {"ok": false}
				state.write_value("state_u16", 21, choice_result)
				cursor = int(contract.resume_offset)
			"script_dispatch_boundary":
				var picture: Array = {1: [0x1615, 0x1622], 2: [0x2238, 0x2245], 3: [0x37B9, 0x37C6]}.get(choice_result, [])
				if entry != "EVENTB03.MES" or picture.is_empty() or event.offset != picture[0] or event.resume != picture[1] or str(terminal.get("target_entry", "")).to_upper() != "B_PIC.MES":
					return {"ok": false}
				var nested := _walk("B_PIC.MES", state, depth + 1, choice_result)
				if not nested.get("ok", false):
					return nested
				cursor = event.resume
			"script_handoff_boundary", "script_return":
				event["end"] = int(terminal.get("end_offset", -1))
				event["target"] = str(terminal.get("target_entry", "")).to_upper()
				if entry == "B_PIC.MES":
					var signature: Array[Dictionary] = []
					for row in _trace.slice(trace_start):
						signature.append({"offset": row.offset, "end": row.end, "effect": row.effect, "resource": str(row.get("resource_name", "")), "routine": int(row.get("routine_id", -1)), "row": int(row.get("cell_row", -1)), "column": int(row.get("cell_column", -1))})
					event["trace_sha256"] = JSON.stringify(signature).sha256_text()
					event["nested_diff"] = state.diff(before)
				_events.append(event)
				return {"ok": true, "terminal": event}
			_:
				# The base audit rejects all additional boundaries. A derived audit
				# must explicitly bind and consume any extra original-source route.
				var additional := _walk_additional_boundary(entry, result, state, context, choice_result)
				if not additional.get("ok", false):
					return additional
				cursor = int(additional.get("resume_offset", -1))
				context["argument_slots"] = additional.get("argument_slots", context.argument_slots).duplicate(true)
				context["persistent_expression_stack"] = additional.get("persistent_expression_stack", context.persistent_expression_stack).duplicate()
		_events.append(event)
	return {"ok": false}


func _walk_additional_boundary(_entry: String, _result: Dictionary, _state: KakyuMesSandboxState, _context: Dictionary, _choice_result: int) -> Dictionary:
	return {"ok": false}


func _append_trace(entry: String, rows: Array) -> void:
	for record in rows:
		var row := {"entry": entry, "offset": int(record.get("source_offset", -1)), "end": int(record.get("end_offset", -1)), "effect": str(record.get("effect", ""))}
		for field in ["resource_name", "routine_id", "cell_row", "cell_column", "write_start", "write_storage", "surface_mode"]:
			if record.has(field):
				row[field] = record[field]
		_trace.append(row)


func _is_state_ref(ast: Dictionary, storage: String, index: int) -> bool:
	return ast.get("type", "") == "state_ref" and ast.get("storage", "") == storage and ast.get("bank", -1) == 0 and ast.get("index", {}).get("type", "") == "literal" and ast.get("index", {}).get("value", -1) == index


func _sha256(bytes: PackedByteArray) -> String:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	return hash_context.finish().hex_encode()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
