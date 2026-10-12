extends SceneTree

const Reader := preload("res://content_core/arc_reader.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const Codec := preload("res://content_core/mmo_codec.gd")
const Plan := preload("res://content_core/mes_mahoko_standing_plan.gd")
const ExpressionScript := preload("res://content_core/mes_expression.gd")
const State := preload("res://content_core/mes_sandbox_state.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const ARCHIVES := ["mes.arc", "mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc"]
const MES_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const PICTURE_SHA256 := "d72612395e8571848a7782ff48d8c63604a09a983ae2c564f2ee5bd5ac2b4ada"
const DATES := [0, 399, 400, 401, 413, 615, 616, 915, 916, 1115, 1116, 1510, 1511, 65535]
const GUARDS := [0x02C0, 0x036A, 0x0414, 0x04BE]
const MARKERS := [0x02E5, 0x038F, 0x0439, 0x04E3]
const LIMITS := [[400, 616], [615, 916], [915, 1116], [1115, 1511]]
const MEDIA_SHA256 := {
	"B1.MMO": "f6c910b31296b0f97394eba78b34bcc6bf287df995b62bbd8c5c12258bb3343c",
	"B2.MMO": "c33b01d3321d1ef51bd2601343085c93dfb45fe12b395c4e7ebdb002f145e004",
	"B3.MMO": "54c70478e72da6e8a5ba32b6a65c6d24eaaeb2470c6c949fbef418a31f54fffe",
	"B4.MMO": "b4a5dc06c678005b950ea8e0a33269a2f227d659f5adcd2e3d009b4d5bde510e",
}
var _checks := 0
var _failures: Array[String] = []
var _plans := Plan.new()
var _decoder := Decoder.new()


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_mahoko_standing_plan.gd -- <ELFIMAGE-directory>")
		quit(2)
		return
	var root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before := {}
	for archive in ARCHIVES:
		if not FileAccess.file_exists(root.path_join(archive)):
			push_error("Required original archive unavailable: %s" % archive)
			quit(2)
			return
		before[archive] = FileAccess.get_sha256(root.path_join(archive))
	_check(before["mes.arc"] == MES_SHA256, "original mes.arc identity changed")
	var mes := Reader.new()
	var mmo := Reader.new()
	_check(mes.open(root.path_join("mes.arc")), "original mes.arc unavailable")
	_check(mmo.open(root.path_join("mmo.arc")), "original mmo.arc unavailable")
	if _failures.is_empty():
		_audit(mes, mmo)
	mes.close()
	mmo.close()
	for archive in ARCHIVES:
		_check(FileAccess.get_sha256(root.path_join(archive)) == before[archive], "%s changed during audit" % archive)
	if not _failures.is_empty():
		push_error("Mahoko standing source audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: Mahoko standing source plan: %d checks / 14 boundary plans and JSON round trips / 65,536 unsigned-word source-condition inputs / 4 original 640x400 MMO assets. Both copies remain symbolic; routine22 and the face join remain unexecuted boundaries. Six archives unchanged. %s / %s. No new playback preset, calendar-validity, native cadence or event-eligibility claim." % [_checks, Version.CORE_VERSION, Version.MES_MAHOKO_STANDING_PLAN_SCHEMA])
	quit(0)


func _audit(mes: RefCounted, mmo: RefCounted) -> void:
	_check(mes.get_entry_fingerprint("B_PIC.MES") == PICTURE_SHA256, "original picture entry identity changed")
	var payload: PackedByteArray = mes.read_entry("B_PIC.MES")
	var doc: Dictionary = ContainerScript.new().parse(payload)
	_check(doc.get("ok", false), "picture container unavailable")
	if not _failures.is_empty():
		return
	var code: PackedByteArray = doc.bytecode
	_validate_source_records(code)
	if not _failures.is_empty():
		return
	_validate_unsigned_domain(code)
	var reached := {}
	for date in DATES:
		var plan: Dictionary = _plans.build(payload, date)
		_check(plan.get("ok", false), "original plan failed at numeric date %d" % date)
		if plan.get("ok", false):
			_validate_plan(plan, payload, doc, date)
			reached[_band(date)] = true
	_check(reached.size() == 5, "boundary plans did not cover four standing arms and the no-load join")
	for name in MEDIA_SHA256:
		_check(mmo.get_entry_fingerprint(name) == MEDIA_SHA256[name], "%s original fingerprint changed" % name)
		var decoded: Dictionary = Codec.new().decode_image(mmo.read_entry(name))
		_check(decoded.get("ok", false), "%s could not be decoded" % name)
		if decoded.get("ok", false):
			_check(decoded.image.get_size() == Vector2i(640, 400), "%s is not 640x400" % name)
	_validate_rejections(payload)
	_check(ContractValues.sha256_lenient(payload) == PICTURE_SHA256, "audit changed its in-memory original payload")


func _validate_source_records(code: PackedByteArray) -> void:
	var first := _record(code, 0x02A5, 0x02B6, "branch_if_not_true")
	if not first.is_empty():
		_check(_ast(first.operands[0].value.ast) == ["logical_or", ["equal", ["global_u8", 0, 206], 1], ["equal", ["global_u8", 0, 206], 3]] and first.operands[1].value == 0x0568, "original g206 guard changed; proof input is still restricted to one")
	for offset in [0x02B6, 0x02BB]:
		_record(code, offset, offset + 5, "source_line_marker")
	for index in range(4):
		var offset: int = GUARDS[index]
		var marker: int = MARKERS[index]
		var guard := _record(code, offset, offset + 19, "branch_if_not_true")
		if not guard.is_empty():
			var expected := ["logical_and", ["greater_than", ["state_u16", 0, 7], LIMITS[index][0]], ["less_than", ["state_u16", 0, 7], LIMITS[index][1]]]
			_check(_ast(guard.operands[0].value.ast) == expected and guard.operands[1].value == (GUARDS[index + 1] if index < 3 else 0x0568), "date guard AST or false edge changed at 0x%X" % offset)
		for line in [offset + 19, offset + 24, marker + 123, marker + 128]:
			_record(code, line, line + 5, "source_line_marker")
		for row in [[marker - 8, marker - 1, 2], [marker + 11, marker + 18, 7]]:
			var write := _record(code, row[0], row[1], "banked_u16_write_run")
			if not write.is_empty():
				_check(_ast(write.operands[0].value.ast) == 1 and write.operands[1].value == 0 and write.operands[2].pairs.size() == 1, "active surface write destination changed")
				_check(_ast(write.operands[2].pairs[0].expression.ast) == row[2] and write.operands[2].pairs[0].continuation == 0, "active surface write value changed")
		var resource := _record(code, marker, marker + 11, "mmo_resource_marker")
		if not resource.is_empty():
			_check(str(resource.operands[0].name).to_upper() == "B%d.MMO" % (index + 1) and resource.operands[0].outer_command_source_offset == marker - 1 and code[marker - 1] == 0x0D, "MMO marker or native outer prefix changed")
		for row in [[marker + 18, marker + 55, 0], [marker + 55, marker + 112, 1]]:
			var copy := _record(code, row[0], row[1], "surface_operation")
			if not copy.is_empty():
				_check(copy.operands[0].mode == row[2] and copy.operands[0].native_operation_semantics == _semantics(row[2]), "copy native mode changed")
				_check(copy.operands[0].expressions.map(func(value): return _ast(value.ast)) == _copy_shapes(row[2]), "source copy dynamic AST changed")
		var flag := _record(code, marker + 112, marker + 118, "global_u8_write_run")
		if not flag.is_empty():
			_check(flag.operands[0].value == 4000 and flag.operands[1].pairs.size() == 1 and _ast(flag.operands[1].pairs[0].expression.ast) == 1 and flag.operands[1].pairs[0].continuation == 0, "pre-refresh flag record changed")
		var call := _record(code, marker + 118, marker + 123, "script_transfer")
		if not call.is_empty():
			_check(call.operands[0].records.size() == 1 and _ast(call.operands[0].records[0].value.ast) == 22, "routine22 stop changed")


func _validate_unsigned_domain(code: PackedByteArray) -> void:
	# Decode four original expressions once: this is not 65,536 hash/build calls.
	var expressions := []
	for offset in GUARDS:
		expressions.append(_decoder.decode_at_structural(code, offset, offset + 19).operands[0].value.ast)
	var evaluator := ExpressionScript.new()
	var state := State.new(19)
	state.write_value("global_u8", 206, 1)
	state.write_value("state_u16", 7, 0)
	var populations := [0, 0, 0, 0, 0]
	var untouched := state.snapshot()
	for date in range(65536):
		state.write_value("state_u16", 7, date)
		var selected := 0
		var matches := 0
		for index in range(4):
			var result: Dictionary = evaluator.evaluate(expressions[index], state)
			if not result.get("ok", false) or int(result.get("value", -1)) not in [0, 1]:
				_check(false, "source date expression failed at %d" % date)
				return
			if result.value == 1:
				selected = index + 1
				matches += 1
		_check(selected == _band(date) and matches <= 1, "source date predicate disagrees with independent numeric interval at %d" % date)
		populations[selected] += 1
	state.write_value("state_u16", 7, 0)
	_check(state.snapshot() == untouched, "source expression evaluation changed state or RNG")
	_check(populations == [64426, 215, 300, 200, 395], "source interval populations changed")


func _validate_plan(plan: Dictionary, payload: PackedByteArray, doc: Dictionary, date: int) -> void:
	var band := _band(date)
	_check(plan.keys().size() == 10 and plan.get("ok", false) and plan.schema == Version.MES_MAHOKO_STANDING_PLAN_SCHEMA, "plan schema or root key set changed")
	_check(plan.producer == {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}, "plan producer identity changed")
	_check(plan.source == {"archive": "mes.arc", "entry": "B_PIC.MES", "entry_sha256": PICTURE_SHA256, "bytecode_sha256": doc.bytecode_sha256, "offset_basis": "code_start", "offset": 0x02A5, "end_offset": 0x0568}, "plan source qualification changed")
	_check(plan.input == {"mmdd": date, "g206": 1}, "plan numeric input or fixed g206 changed")
	_check(plan.execution == {"kind": "read_only_projection", "state_mutation": false, "compatibility": "remake_only", "native_cadence": "unresolved", "event_eligibility": "unqualified"}, "proof was promoted to native execution or eligibility")
	var guards := [{"offset": 0x02A5, "end_offset": 0x02B6, "value": 1, "next_offset": 0x02B6}]
	for index in range(4 if band == 0 else band):
		var yes := index + 1 == band
		guards.append({"offset": GUARDS[index], "end_offset": GUARDS[index] + 19, "value": 1 if yes else 0, "next_offset": GUARDS[index] + 19 if yes else (GUARDS[index + 1] if index < 3 else 0x0568)})
	_check(plan.guards == guards, "plan guard route changed at %d" % date)
	if band == 0:
		_check(plan.selection == {} and plan.copies == [], "no-load source path fabricated a standing image or copy")
		_check(plan.boundary == {"kind": "face_join", "offset": 0x0568, "end_offset": 0x0568, "routine_id": -1}, "no-load source face join changed")
	else:
		var marker: int = MARKERS[band - 1]
		_check(plan.selection == {"entry": "B%d.MMO" % band, "offset": marker, "end_offset": marker + 11, "outer_command_offset": marker - 1, "load_surface": 2}, "selected MMO record changed at %d" % date)
		_check(plan.boundary == {"kind": "shared_routine", "offset": marker + 118, "end_offset": marker + 123, "routine_id": 22}, "selected routine22 boundary changed")
		_check(plan.copies.size() == 2, "selected plan lost a symbolic copy")
		if plan.copies.size() == 2:
			for row in [[marker + 18, marker + 55, 0], [marker + 55, marker + 112, 1]]:
				var record: Dictionary = _decoder.decode_at_structural(doc.bytecode, row[0], row[1])
				var asts: Array = record.operands[0].expressions.map(func(value): return value.ast)
				_check(plan.copies[row[2]] == {"offset": row[0], "end_offset": row[1], "mode": row[2], "expressions": asts, "native_operation_semantics": _semantics(row[2]), "active_surface": 7, "evaluation": "symbolic_not_evaluated"}, "copy failed to retain exact source AST and unevaluated contract")
	var original := JSON.stringify(plan)
	_check(_plans.validate(payload, plan).get("ok", false), "native source plan failed replay validation")
	var reloaded: Dictionary = JSON.parse_string(original)
	_check(_plans.validate(payload, reloaded).get("ok", false), "original plan failed JSON round-trip validation")
	_check(_plans.build(payload, date) == plan and JSON.stringify(plan) == original, "repeated construction or validation changed plan inputs")
	if band != 0:
		var changed: Dictionary = plan.duplicate(true)
		changed.copies[0].expressions[0].value = 99
		_check(not _plans.validate(payload, changed).get("ok", true) and _plans.build(payload, date) == plan, "mutated output AST contaminated future source proof")


func _validate_rejections(payload: PackedByteArray) -> void:
	for value in [null, true, false, "413", 413.0, 413.5, -1, 65536, INF, -INF, NAN, [], {}]:
		_check(not _plans.build(payload, value).get("ok", true), "invalid date input accepted")
	var plan: Dictionary = _plans.build(payload, 413)
	if not plan.get("ok", false):
		return
	var saved := JSON.stringify(plan)
	for offset in [0, 100, payload.size() - 1]:
		var changed := payload.duplicate()
		changed[offset] ^= 1
		_check(not _plans.build(changed, 413).get("ok", true) and not _plans.validate(changed, plan).get("ok", true), "mutated source payload accepted")
	for end in [0, 3, payload.size() - 1]:
		_check(not _plans.build(payload.slice(0, end), 413).get("ok", true), "truncated source payload accepted")
	for mutation in [
		[["schema"], "unqualified"], [["ok"], false], [["extra"], 1], [["producer", "core_version"], "unqualified"],
		[["source", "entry"], "OTHER.MES"], [["source", "entry_sha256"], "unqualified"], [["source", "offset"], 0x02A6],
		[["input", "mmdd"], 616], [["input", "g206"], 3], [["input", "g206"], true], [["input", "mmdd"], "413"],
		[["input", "mmdd"], 413.5],
		[["selection", "entry"], "B2.MMO"], [["selection", "offset"], 0x02E6], [["selection", "end_offset"], 0x02F1],
		[["selection", "outer_command_offset"], 0x02E5], [["selection", "load_surface"], 7],
		[["copies", 0, "mode"], 1], [["copies", 1, "mode"], true], [["copies", 0, "offset"], 759.5],
		[["copies", 0, "expressions", 0, "value"], false], [["copies", 1, "expressions", 1, "bank"], 1],
		[["copies", 1, "expressions", 1, "index", "value"], 18], [["copies", 1, "expressions", 1, "source", "offset"], 0],
		[["copies", 1, "native_operation_semantics"], "opaque_rectangle_copy_confirmed"],
		[["copies", 1, "evaluation"], "evaluated"], [["copies", 1, "active_surface"], 2],
		[["boundary", "kind"], "face_join"], [["boundary", "routine_id"], 8], [["boundary", "end_offset"], 0x0361],
		[["guards"], []], [["guards", 0, "value"], true], [["execution", "state_mutation"], true],
		[["execution", "state_mutation"], 0], [["execution", "event_eligibility"], "qualified"],
		[["copies"], [plan.copies[1], plan.copies[0]]], [["copies", 1, "expressions"], []],
	]:
		var changed: Dictionary = plan.duplicate(true)
		var parent: Variant = changed
		var path: Array = mutation[0]
		for index in range(path.size() - 1):
			parent = parent[path[index]]
		parent[path[-1]] = mutation[1]
		var before := JSON.stringify(changed)
		_check(not _plans.validate(payload, changed).get("ok", true) and JSON.stringify(changed) == before, "mutated plan accepted or rewritten: %s" % str(path))
	for value in [NAN, INF, -INF]:
		var changed: Dictionary = plan.duplicate(true)
		changed.input.mmdd = value
		var rejected := not bool(_plans.validate(payload, changed).get("ok", true))
		_check(rejected and typeof(changed.input.mmdd) == TYPE_FLOAT and (is_nan(changed.input.mmdd) if is_nan(value) else changed.input.mmdd == value), "nonfinite plan input rejects without rewriting the numeric value")
	for nested in [false, true]:
		var missing: Dictionary = plan.duplicate(true)
		var extra: Dictionary = plan.duplicate(true)
		var missing_target: Dictionary = missing.copies[1].expressions[1] if nested else missing
		var extra_target: Dictionary = extra.copies[1].expressions[1] if nested else extra
		missing_target.erase("source" if nested else "schema")
		extra_target["unqualified"] = 1
		_check(not _plans.validate(payload, missing).get("ok", true) and not _plans.validate(payload, extra).get("ok", true), "missing/extra exact plan key accepted")
	var no_load: Dictionary = _plans.build(payload, 0)
	var fabricated := no_load.duplicate(true)
	fabricated.selection = plan.selection.duplicate(true)
	_check(not _plans.validate(payload, fabricated).get("ok", true), "no-load join accepted an invented standing selection")
	fabricated = no_load.duplicate(true)
	fabricated.copies = plan.copies.duplicate(true)
	_check(not _plans.validate(payload, fabricated).get("ok", true), "no-load join accepted invented copy effects")
	_check(JSON.stringify(plan) == saved and _plans.validate(payload, plan).get("ok", false), "negative probes changed the original valid plan")


func _band(date: int) -> int:
	# Independent inclusive numeric interval oracle, not the helper implementation.
	if date >= 401 and date <= 615: return 1
	if date >= 616 and date <= 915: return 2
	if date >= 916 and date <= 1115: return 3
	if date >= 1116 and date <= 1510: return 4
	return 0


func _copy_shapes(mode: int) -> Array:
	var x := ["banked_u16", 0, 17]
	var y := ["banked_u16", 0, 18]
	var destination := ["banked_u16", 0, 23]
	return [0, 0, 0, 639, 399, 1, 0, 0, destination] if mode == 0 else [1, x, y, ["subtract", ["add", x, ["banked_u16", 0, 19]], 1], ["subtract", ["add", y, ["banked_u16", 0, 20]], 1], 2, x, y, destination]


func _semantics(mode: int) -> String:
	return ["opaque_rectangle_copy_confirmed", "rgb_chroma_key_rectangle_copy_confirmed"][mode]


func _record(code: PackedByteArray, offset: int, end: int, operation: String) -> Dictionary:
	var record: Dictionary = _decoder.decode_at_structural(code, offset, end)
	var valid: bool = record.get("ok", false) and record.get("op", "") == operation and record.get("end_offset", -1) == end
	_check(valid, "%s record boundary changed at 0x%X" % [operation, offset])
	return record if valid else {}


func _ast(ast: Dictionary) -> Variant:
	match str(ast.get("type", "")):
		"literal": return ast.get("value")
		"state_ref": return [ast.get("storage"), ast.get("bank"), _ast(ast.get("index", {}))]
		"binary": return [ast.get("op"), _ast(ast.get("lhs", {})), _ast(ast.get("rhs", {}))]
	return {"unsupported": ast.get("type", "missing")}


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)
