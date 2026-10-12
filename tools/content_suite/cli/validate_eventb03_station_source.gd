extends SceneTree

# Read-only, source-qualified station selection assertions. Pass mes.arc as the sole CLI argument.
# Exact resource selection and surface copies are checked; native host refresh/cadence are not executed.
const Reader = preload("res://content_core/arc_reader.gd")
const MesContainer = preload("res://content_core/mes_container.gd")
const Decoder = preload("res://content_core/mes_instruction_decoder.gd")
const Library = preload("res://content_core/mes_library_index.gd")
const ExpressionScript = preload("res://content_core/mes_expression.gd")
const State = preload("res://content_core/mes_sandbox_state.gd")
var decoder = Decoder.new()
var expression = ExpressionScript.new()
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_eventb03_station_source.gd -- <mes.arc>")
		quit(1)
		return
	var arc_path: String = ProjectSettings.globalize_path(arguments[0]).simplify_path()
	if not FileAccess.file_exists(arc_path) or not FileAccess.file_exists(arc_path.get_base_dir().path_join("mmo.arc")):
		push_error("The supplied mes.arc or adjacent mmo.arc is unavailable.")
		quit(1)
		return
	var archive_hash := FileAccess.get_sha256(arc_path)
	var arc := Reader.new()
	_check(arc.open(arc_path))
	var station := _code(arc, "01M.MES", "a50511b0ad0ad446b7988c3cfb36736424bf6617e9eb952e20b505f745607cc5")
	var event := _code(arc, "EVENTB03.MES", "558532a9b034522db857d009132b6a89aa488e577277857cc90ce337c95ee230")
	var lib := _code(arc, "LIBLARY.LIB", "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d")
	var index: Dictionary = Library.new().build(lib)
	_check(index.ok and index.by_id[27].body_offset == 0x3548 and index.by_id[27].end_offset == 0xE0BC)
	# Both original station intro and event tail supply the same selector11.
	for row in [[station, 0x1D1, 0x1D8, 0x1DE, 0x1E3], [event, 0x3715, 0x371C, 0x3722, 0x3727]]:
		var active := _instruction(row[0], row[1], row[2], "banked_u16_write_run")
		_check(active.operands[0].value.ast.value == 1 and active.operands[1].value == 0)
		_check(active.operands[2].pairs[0].expression.ast.value == 1)
		var selector := _instruction(row[0], row[2], row[3], "argument_slot_write_run")
		_check(selector.operands[0].value == 1 and selector.operands[1].pairs[0].expression.ast.value == 11)
		var call := _instruction(row[0], row[3], row[4], "script_transfer")
		_check(call.operands[0].records.size() == 1 and call.operands[0].records[0].value.ast.value == 27)
	var state := State.new()
	state.write_value("global_i32", 1, 11)
	state.write_value("state_u16", 7, 413)
	state.write_value("state_u16", 19, 1825)
	for row in [[0x3548, 0x3553, 0, 0x35B8], [0x35B8, 0x35C3, 0, 0x3B3C], [0x3B3C, 0x3B47, 1, 0x3B47], [0x3B47, 0x3B61, 1, 0x3B61], [0x3B61, 0x3B6D, 0, 0x3BD4], [0x3BD4, 0x3BE0, 0, 0x3C47], [0x3C47, 0x3C53, 0, 0x3CBA]]:
		_branch(lib, row, state)
	# The season predicate has two disjoint accepted spans, not a guessed filename suffix.
	var date_branch := _instruction(lib, 0x3B47, 0x3B61, "branch_if_not_true")
	for row in [[413, 1], [615, 1], [616, 0], [915, 0], [916, 1], [1115, 1], [1116, 0]]:
		state.write_value("state_u16", 7, row[0])
		var evaluated: Dictionary = expression.evaluate(date_branch.operands[0].value.ast, state)
		_check(evaluated.ok and evaluated.value == row[1])
	state.write_value("state_u16", 7, 413)
	var set_surface := _instruction(lib, 0x3CBA, 0x3CC1, "banked_u16_write_run")
	_check(set_surface.operands[0].value.ast.value == 1 and set_surface.operands[1].value == 0)
	_check(set_surface.operands[2].pairs[0].expression.ast.value == 2)
	var marker := _instruction(lib, 0x3CC2, 0x3CD1, "mmo_resource_marker")
	_check(marker.operands[0].name.to_upper() == "01MA_3.MMO")
	_check(marker.operands[0].outer_command_source_offset == 0x3CC1)
	_check(marker.operands[0].native_active_surface_storage_index == 1)
	_check(marker.operands[0].native_active_surface_bank == 0)
	set_surface = _instruction(lib, 0x3CD1, 0x3CD8, "banked_u16_write_run")
	_check(set_surface.operands[2].pairs[0].expression.ast.value == 7)
	var copy := _instruction(lib, 0x3CD8, 0x3CFB, "surface_operation")
	_check(copy.operands[0].mode == 1)
	_check(copy.operands[0].native_operation_semantics == "rgb_chroma_key_rectangle_copy_confirmed")
	_check(_values(copy, state) == [1, 0, 0, 639, 399, 2, 0, 0, 1])
	var refresh := _instruction(lib, 0x3CFB, 0x3D00, "script_transfer")
	_check(refresh.operands[0].records[0].value.ast.value == 8)
	# Routine8 and both event restoration arms read the surface1 producer above.
	for row in [[lib, 0x299, 0x2BE], [lib, 0x3F2, 0x417], [event, 0x373E, 0x3763]]:
		copy = _instruction(row[0], row[1], row[2], "surface_operation")
		_check(copy.operands[0].mode == 0)
		var values := _values(copy, state)
		_check(values.slice(0, 8) == [0, 0, 0, 639, 399, 1, 0, 0])
		_check(copy.operands[0].expressions[8].ast.storage == "banked_u16" and copy.operands[0].expressions[8].ast.index.value == 23)
	var mmo_path := arc_path.get_base_dir().path_join("mmo.arc")
	var mmo_hash := FileAccess.get_sha256(mmo_path)
	var mmo := Reader.new()
	_check(mmo.open(mmo_path))
	_check(mmo.get_entry_fingerprint("01MA_3.MMO") == "a523cf5d07fb3987800bb50764e010781d6b996e2495d354d2aeb946048a2bef")
	var decoded: Dictionary = preload("res://content_core/mmo_codec.gd").new().decode_image(mmo.read_entry("01MA_3.MMO"))
	_check(decoded.ok and decoded.image.get_size() == Vector2i(640, 400))
	_check(FileAccess.get_sha256(arc_path) == archive_hash and FileAccess.get_sha256(mmo_path) == mmo_hash)
	if not failures.is_empty():
		quit(1)
		return
	print("B03_STATION_SOURCE_ASSERTIONS PASS checks=", checks, " selected=01MA_3.MMO selector=11 date=413 time=1825 producer=LIBLARY.LIB:0x3CC2 surface_copy=2->1 native_refresh_lifetime=unresolved")
	quit()
func _code(arc: RefCounted, entry: String, expected: String) -> PackedByteArray:
	_check(arc.get_entry_fingerprint(entry) == expected)
	var doc: Dictionary = MesContainer.new().parse(arc.read_entry(entry))
	_check(doc.ok)
	return doc.bytecode
func _instruction(code: PackedByteArray, start: int, end: int, op: String) -> Dictionary:
	var instruction: Dictionary = decoder.decode_at_structural(code, start)
	_check(instruction.ok and instruction.end_offset == end and instruction.op == op)
	return instruction
func _branch(code: PackedByteArray, row: Array, state: RefCounted) -> void:
	var instruction := _instruction(code, row[0], row[1], "branch_if_not_true")
	var result: Dictionary = expression.evaluate(instruction.operands[0].value.ast, state)
	_check(result.ok and result.value == row[2])
	_check((instruction.end_offset if result.value == 1 else instruction.operands[1].value) == row[3])
func _values(instruction: Dictionary, state: RefCounted) -> Array:
	var values: Array = []
	for expr in instruction.operands[0].expressions:
		var result: Dictionary = expression.evaluate(expr.ast, state)
		_check(result.ok)
		values.append(result.value)
	return values
func _check(value: bool) -> void:
	checks += 1
	if not value:
		var message := "Source assertion failed at check %d" % checks
		failures.append(message)
		push_error(message)
		quit(1)
