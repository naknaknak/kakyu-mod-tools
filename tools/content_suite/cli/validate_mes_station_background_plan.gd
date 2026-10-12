extends SceneTree

# Metadata-only original-source proof. No plan, pixels or archive payload is exported.
const Reader := preload("res://content_core/arc_reader.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const Decoder := preload("res://content_core/mes_instruction_decoder.gd")
const Codec := preload("res://content_core/mmo_codec.gd")
const Plan := preload("res://content_core/mes_station_background_plan.gd")
const Version := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const MES_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const LIBRARY_SHA256 := "d9aba6eb8dab51fe321e22c868ed0cf38416bba1f0cf2f5d7d719f48e89b8b4d"
const ARCHIVES := ["mes.arc", "mmo.arc", "data.arc", "bgm.arc", "se.arc", "voice.arc"]
const DATES := [0, 413, 615, 616, 915, 916, 1115, 1116, 65535]
const TIMES := [0, 599, 600, 1559, 1600, 1759, 1800, 1825, 65535]
const FAMILIES := {
	"A": {"guards": [0x3B61, 0x3BD4, 0x3C47], "markers": [0x3B75, 0x3BE8, 0x3C5B, 0x3CC2]},
	"S": {"guards": [0x3D34, 0x3DA7, 0x3E1A], "markers": [0x3D48, 0x3DBB, 0x3E2E, 0x3E95]},
	"M": {"guards": [0x3F00, 0x3F73, 0x3FE6], "markers": [0x3F14, 0x3F87, 0x3FFA, 0x4061]},
}
const MEDIA_SHA256 := {
	"01MA_1.MMO": "5227c6bacb4470b0de537fbed41c2c3c26485b0dc457b781c7bac6c55a66d168",
	"01MA_2.MMO": "5e9511f7b362e2bd4daf70a0ff35266f55f9b49b450005eab03943f3fd399515",
	"01MA_3.MMO": "a523cf5d07fb3987800bb50764e010781d6b996e2495d354d2aeb946048a2bef",
	"01MS_1.MMO": "8c900338563012f90f14b0fc19c62b5406f18aa922078fe451b29c4c820d2b16",
	"01MS_2.MMO": "a2ca53209ff624c6e7dada6b30f2da7ce8aebf923cf33940ea4ff9a3ea18bd07",
	"01MS_3.MMO": "8dac3d056f869abbadb4a4d6c75373e40e84656b11833a01326555e259f39890",
	"01MM_1.MMO": "bba7c18f0dd9261f68560d5db2a9e8c3ef0b2843c57a6f6449ec43b0ebb2547d",
	"01MM_2.MMO": "363b918b832ec98067497f90e1ff3237a6fb884a6360dcd017a557e792f31881",
	"01MM_3.MMO": "45a5e7c272997b13d9fdcb0e2509e93baec26f7897f1286f0e42b19ebb6c7b82",
}
var _checks := 0
var _failures: Array[String] = []
var _plans := Plan.new()
var _decoder := Decoder.new()


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Usage: validate_mes_station_background_plan.gd -- <ELFIMAGE-directory>")
		quit(2)
		return
	var root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var before := {}
	for archive in ARCHIVES:
		var path := root.path_join(archive)
		if not FileAccess.file_exists(path):
			push_error("Required original archive unavailable: %s" % archive)
			quit(2)
			return
		before[archive] = FileAccess.get_sha256(path)
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
		push_error("Station background source audit failed: %s" % "; ".join(_failures))
		quit(1)
		return
	print("PASS: station background source plan: %d checks / 81 unsigned-word input pairs / 12 load arms / 9 original MMO assets. Routine8 is an unexecuted stop boundary; six archives unchanged. %s / %s. No new playback preset, native cadence, calendar-validity or event-eligibility claim." % [_checks, Version.CORE_VERSION, Version.MES_STATION_BACKGROUND_PLAN_SCHEMA])
	quit(0)


func _audit(mes: RefCounted, mmo: RefCounted) -> void:
	_check(mes.get_entry_fingerprint("LIBLARY.LIB") == LIBRARY_SHA256, "original library entry identity changed")
	var payload: PackedByteArray = mes.read_entry("LIBLARY.LIB")
	var doc: Dictionary = ContainerScript.new().parse(payload)
	_check(doc.get("ok", false), "library container unavailable")
	if not _failures.is_empty():
		return
	var code: PackedByteArray = doc.bytecode
	_check(ContractValues.sha256_lenient(payload) == LIBRARY_SHA256, "library payload fingerprint changed")
	_validate_source_guards(code)
	var seen_arms := {}
	var seen_media := {}
	for date in DATES:
		for time in TIMES:
			var plan: Dictionary = _plans.build(payload, date, time)
			_check(plan.get("ok", false), "plan rejected unsigned-word input %d/%d: %s" % [date, time, plan.get("error", "")])
			if not plan.get("ok", false):
				continue
			_validate_plan(plan, payload, doc, date, time)
			seen_arms[plan.selection.offset] = true
			seen_media[plan.selection.entry] = true
	_check(seen_arms.size() == 12, "matrix did not reach all twelve source arms")
	_check(seen_media.size() == 9, "matrix did not select all nine station MMO entries")
	for name in MEDIA_SHA256:
		var actual: String = mmo.get_entry_fingerprint(name)
		print("STATION_MEDIA ", name, " sha256=", actual)
		_check(actual == MEDIA_SHA256[name] and not actual.is_empty(), "%s fingerprint changed" % name)
		var decoded: Dictionary = Codec.new().decode_image(mmo.read_entry(name))
		_check(decoded.get("ok", false), "%s could not be decoded" % name)
		if decoded.get("ok", false):
			_check(decoded.image.get_size() == Vector2i(640, 400), "%s is not 640x400" % name)
	_validate_rejections(payload)
	_check(ContractValues.sha256_lenient(payload) == LIBRARY_SHA256, "audit changed its in-memory source payload")


func _validate_source_guards(code: PackedByteArray) -> void:
	var date := ["state_u16", 0, 7]
	var time := ["state_u16", 0, 19]
	var expected := [
		[0x3B3C, 0x3B47, ["equal", ["global_i32", 0, 1], 11], 0x40C0],
		[0x3B47, 0x3B61, ["logical_or", ["less_than", date, 616], ["logical_and", ["greater_than", date, 915], ["less_than", date, 1116]]], 0x3D21],
		[0x3D21, 0x3D34, ["logical_and", ["greater_than", date, 615], ["less_than", date, 916]], 0x3EF4],
		[0x3EF4, 0x3F00, ["greater_than", date, 1115], 0x40BB],
	]
	for family in FAMILIES.values():
		for index in range(3):
			var offset: int = family.guards[index]
			var next: int = family.guards[index + 1] if index < 2 else family.markers[3] - 8
			expected.append([offset, offset + 12, ["less_than", time, [600, 1600, 1800][index]], next])
	for row in expected:
		var guard := _record(code, row[0], row[1], "branch_if_not_true")
		if guard.is_empty():
			continue
		_check(_ast(guard.operands[0].value.ast) == row[2], "guard AST changed at 0x%X" % row[0])
		_check(guard.operands[1].value == row[3], "false target changed at 0x%X" % row[0])
	for family in FAMILIES:
		for index in range(4):
			var marker: int = FAMILIES[family].markers[index]
			var resource := _record(code, marker, marker + 15, "mmo_resource_marker")
			if not resource.is_empty():
				_check(str(resource.operands[0].name).to_upper() == _entry(family, index), "marker identity changed at 0x%X" % marker)
			for row in [[marker - 8, marker - 1, 2], [marker + 15, marker + 22, 7]]:
				var write := _record(code, row[0], row[1], "banked_u16_write_run")
				if not write.is_empty():
					_check(_ast(write.operands[0].value.ast) == 1 and write.operands[1].value == 0, "active-surface storage identity changed")
					var pairs: Array = write.operands[2].pairs
					_check(pairs.size() == 1 and _ast(pairs[0].expression.ast) == row[2] and pairs[0].continuation == 0, "active-surface write value changed")
			var copy := _record(code, marker + 22, marker + 57, "surface_operation")
			if not copy.is_empty():
				var values: Array = copy.operands[0].expressions.map(func(value): return _ast(value.ast))
				_check(copy.operands[0].mode == 1 and values == [1, 0, 0, 639, 399, 2, 0, 0, 1], "explicit source-2 destination-1 copy changed")
			var call := _record(code, marker + 57, marker + 62, "script_transfer")
			if not call.is_empty():
				var records: Array = call.operands[0].records
				_check(records.size() == 1 and _ast(records[0].value.ast) == 8, "unexecuted refresh boundary changed")


func _validate_plan(plan: Dictionary, payload: PackedByteArray, doc: Dictionary, date: int, time: int) -> void:
	var family := "A" if date < 616 or (date > 915 and date < 1116) else ("S" if date > 615 and date < 916 else "M")
	var index := 0 if time < 600 else (1 if time < 1600 else (2 if time < 1800 else 3))
	var marker: int = FAMILIES[family].markers[index]
	_check(plan.schema == Version.MES_STATION_BACKGROUND_PLAN_SCHEMA, "plan schema changed")
	_check(plan.producer == {"core_version": Version.CORE_VERSION, "instruction_schema": Version.MES_INSTRUCTION_SCHEMA}, "plan producer changed")
	_check(plan.source == {"archive": "mes.arc", "entry": "LIBLARY.LIB", "entry_sha256": LIBRARY_SHA256, "bytecode_sha256": doc.bytecode_sha256, "routine_id": 27, "selector": 11, "offset_basis": "code_start", "offset": 0x3B3C, "end_offset": 0x40C0}, "plan source qualification changed")
	_check(plan.input == {"mmdd": date, "hhmm": time}, "plan numeric inputs changed")
	_check(plan.selection == {"entry": _entry(family, index), "offset": marker, "end_offset": marker + 15, "outer_command_offset": marker - 1, "load_surface": 2}, "selected resource/producer changed at %d/%d" % [date, time])
	_check(plan.copy == {"offset": marker + 22, "end_offset": marker + 57, "mode": 1, "source_surface": 2, "destination_surface": 1, "source_rect": [0, 0, 640, 400], "destination": [0, 0], "active_surface": 7}, "source copy contract changed")
	_check(plan.boundary == {"offset": marker + 57, "end_offset": marker + 62, "routine_id": 8}, "routine8 stop boundary changed")
	_check(plan.execution == {"kind": "read_only_projection", "state_mutation": false, "compatibility": "remake_only", "native_cadence": "unresolved", "event_eligibility": "unqualified"}, "plan was promoted to execution or event eligibility")
	var guards := [_guard(0x3B3C, 0x3B47, 1, 0x3B47), _guard(0x3B47, 0x3B61, 1 if family == "A" else 0, 0x3B61 if family == "A" else 0x3D21)]
	if family != "A":
		guards.append(_guard(0x3D21, 0x3D34, 1 if family == "S" else 0, 0x3D34 if family == "S" else 0x3EF4))
		if family == "M":
			guards.append(_guard(0x3EF4, 0x3F00, 1, 0x3F00))
	for guard_index in range(mini(index + 1, 3)):
		var offset: int = FAMILIES[family].guards[guard_index]
		var value := 1 if guard_index == index else 0
		var next: int = offset + 12 if value == 1 else (FAMILIES[family].guards[guard_index + 1] if guard_index < 2 else marker - 8)
		guards.append(_guard(offset, offset + 12, value, next))
	_check(plan.guards == guards, "source branch trace changed at %d/%d" % [date, time])
	_check(_plans.validate(payload, plan).get("ok", false), "source-bound plan failed replay validation")
	var reloaded: Variant = JSON.parse_string(JSON.stringify(plan))
	_check(reloaded is Dictionary and _plans.validate(payload, reloaded).get("ok", false), "source-bound plan failed JSON round-trip validation")
	_check(_plans.build(payload, date, time) == plan, "repeated build changed the plan")


func _validate_rejections(payload: PackedByteArray) -> void:
	for inputs in [[-1, 1825], [65536, 1825], [413, -1], [413, 65536], [413.0, 1825], [413, 1825.0], [true, 1825], [413, false], ["413", 1825], [413, null]]:
		_check(not _plans.build(payload, inputs[0], inputs[1]).get("ok", false), "non-word input was accepted")
	var plan: Dictionary = _plans.build(payload, 413, 1825)
	if not plan.get("ok", false):
		return
	for offset in [0, 100, payload.size() - 1]:
		var changed := payload.duplicate()
		changed[offset] ^= 1
		_check(not _plans.build(changed, 413, 1825).get("ok", false), "mutated library payload was accepted")
		_check(not _plans.validate(changed, plan).get("ok", false), "plan accepted with changed source payload")
	_check(not _plans.build(PackedByteArray(), 413, 1825).get("ok", false), "empty source was accepted")
	var mutations := [
		[["schema"], "unqualified"], [["ok"], false], [["extra"], true],
		[["producer", "core_version"], "unqualified"], [["source", "entry_sha256"], "unqualified"],
		[["source", "offset"], 0x3B3D], [["source", "selector"], 12],
		[["input", "mmdd"], 616], [["input", "hhmm"], 600],
		[["input", "mmdd"], 413.5], [["input", "hhmm"], 1825.5],
		[["input", "mmdd"], "413"], [["input", "hhmm"], null], [["input", "mmdd"], true],
		[["selection", "entry"], "01MS_3.MMO"], [["selection", "offset"], 0x3CC3],
		[["selection", "end_offset"], 0x3CD2], [["selection", "outer_command_offset"], 0x3CC0],
		[["selection", "load_surface"], 0], [["copy", "source_surface"], 7],
		[["copy", "destination_surface"], 0], [["copy", "mode"], 0],
		[["copy", "source_rect"], [0, 0, 639, 399]], [["boundary", "routine_id"], 27],
		[["boundary", "end_offset"], 0x3D01], [["execution", "state_mutation"], true],
		[["execution", "event_eligibility"], "qualified"], [["guards"], []], [["input"], []],
		[["copy", "mode"], true], [["copy", "offset"], 15576.5],
		[["source", "routine_id"], 27.5], [["source", "selector"], true],
		[["guards", 0, "value"], true], [["guards", 0, "offset"], 15164.5],
		[["execution", "state_mutation"], 0],
	]
	for mutation in mutations:
		var changed: Dictionary = plan.duplicate(true)
		var parent: Variant = changed
		var path: Array = mutation[0]
		for index in range(path.size() - 1):
			parent = parent[path[index]]
		parent[path[-1]] = mutation[1]
		_check(not _plans.validate(payload, changed).get("ok", false), "mutated plan accepted: %s" % str(path))
	_check(_plans.validate(payload, plan).get("ok", false), "rejected probes changed the valid plan")


func _entry(family: String, index: int) -> String:
	return "01M%s_%d.MMO" % [family, [3, 1, 2, 3][index]]


func _guard(offset: int, end: int, value: int, next: int) -> Dictionary:
	return {"offset": offset, "end_offset": end, "value": value, "next_offset": next}


func _record(code: PackedByteArray, offset: int, end: int, operation: String) -> Dictionary:
	var record: Dictionary = _decoder.decode_at_structural(code, offset, end)
	var valid: bool = record.get("ok", false) and record.get("op", "") == operation and record.get("end_offset", -1) == end
	_check(valid, "%s record boundary changed at 0x%X" % [operation, offset])
	return record if valid else {}


func _ast(ast: Dictionary) -> Variant:
	match str(ast.get("type", "")):
		"literal":
			return ast.get("value")
		"state_ref":
			return [ast.get("storage"), ast.get("bank"), _ast(ast.get("index", {}))]
		"binary":
			return [ast.get("op"), _ast(ast.get("lhs", {})), _ast(ast.get("rhs", {}))]
	return {"unsupported": ast.get("type", "missing")}


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)
