extends "res://tests/test_case.gd"

const GuardFormScript := preload("res://content_core/event_guard_form.gd")

const K_DATE3_PATH := "res://config/event_definitions/v4/ai.date.k_date3.15.1.json"
const D05_PATH := "res://config/event_definitions/v4/maki.town.station.05.1.json"


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _field(fields: Array, storage: String, bank: int, index: int) -> Dictionary:
	for field_value in fields:
		var field: Dictionary = field_value
		if str(field.storage) == storage and int(field.bank) == bank and int(field.index) == index:
			return field
	return {}


func _ready() -> void:
	var k_date3 := _load_json(K_DATE3_PATH)
	var k_date3_conjuncts: Array = k_date3.get("guard", {}).get("conjuncts", [])
	var k_date3_result := GuardFormScript.fields(k_date3_conjuncts)
	var k_date3_fields: Array = k_date3_result.fields
	var k_date3_date := _field(k_date3_fields, "state_u16", 0, 7)
	_check(not k_date3_date.is_empty() and int(k_date3_date.min) == 1116 and int(k_date3_date.max) == 1510 and (k_date3_date.excluded as Array) == [1301], "k_date3 date field: min 1116, max 1510, excludes 1301")
	_check(str(k_date3_date.label) == "date (state_u16[7])", "k_date3 date field label names the cell")
	# The k_date3 guard has three distinct cells: date, clock, global_u8[2341].
	_check(k_date3_fields.size() == 3, "k_date3 guard yields three distinct cell fields")
	var k_date3_clock2 := _field(k_date3_fields, "state_u16", 0, 19)
	_check(not k_date3_clock2.is_empty() and int(k_date3_clock2.min) == 1801, "k_date3 clock field: min 1801")
	var k_date3_flag := _field(k_date3_fields, "global_u8", 0, 2341)
	_check(not k_date3_flag.is_empty() and int(k_date3_flag.fixed) == 0, "k_date3 global_u8[2341] field: fixed 0")

	var d05 := _load_json(D05_PATH)
	var d05_conjuncts: Array = d05.get("guard", {}).get("conjuncts", [])
	var d05_result := GuardFormScript.fields(d05_conjuncts)
	var d05_fields: Array = d05_result.fields
	var weekday := _field(d05_fields, "state_u16", 0, 4)
	_check(not weekday.is_empty() and int(weekday.fixed) == 0, "D05 weekday field: fixed 0")
	var date := _field(d05_fields, "state_u16", 0, 7)
	_check(not date.is_empty() and int(date.min) == 401 and int(date.max) == 615, "D05 date field: min 401, max 615")
	var clock := _field(d05_fields, "state_u16", 0, 19)
	_check(not clock.is_empty() and int(clock.min) == 801 and int(clock.max) == 1600, "D05 clock field: min 801, max 1600")
	var affection := _field(d05_fields, "banked_u16", 0, 212)
	_check(not affection.is_empty() and int(affection.min) == 51 and int(affection.max) == 79, "D05 banked_u16[212] field: min 51, max 79")
	_check(str(affection.label) == "Maki affection (banked_u16[212])", "D05 banked_u16[212] field is labelled Maki's affection")
	var flag_cells := [402, 220, 224, 225, 227, 753, 778, 678]
	var all_flags_fixed := true
	for flag_index in flag_cells:
		var flag_field := _field(d05_fields, "global_u8", 0, flag_index)
		if flag_field.is_empty() or flag_field.fixed == null:
			all_flags_fixed = false
	_check(all_flags_fixed, "D05's flag cells are all fixed")

	# writes(): overriding by key and appending a new key.
	var base_writes := [
		{"storage": "state_u16", "bank": 0, "index": 7, "value": 1313, "evidence_level": "confirmed"},
		{"storage": "global_u8", "bank": 0, "index": 2341, "value": 0, "evidence_level": "confirmed"},
	]
	var values := {"state_u16:0:7": 1200, "state_u16:0:19": 1900}
	var composed := GuardFormScript.writes(k_date3_fields, values, base_writes)
	var by_key := {}
	for write_value in composed:
		var write: Dictionary = write_value
		by_key["%s:%d:%d" % [str(write.storage), int(write.bank), int(write.index)]] = write
	_check(composed.size() == 3, "writes() overrides one key and appends a new one")
	_check(int(by_key["state_u16:0:7"].value) == 1200 and str(by_key["state_u16:0:7"].evidence_level) == "tool_seeded", "writes() overrides the date write, marking it tool_seeded")
	_check(int(by_key["global_u8:0:2341"].value) == 0, "writes() keeps the untouched base write")
	_check(int(by_key["state_u16:0:19"].value) == 1900, "writes() appends the new clock write")

	# key() and writes_by_key() (round 3 code review, item 8): the public
	# helpers the player, the validator and event_catalog.gd all share.
	_check(GuardFormScript.key("state_u16", 0, 7) == "state_u16:0:7", "key() builds the storage:bank:index string")
	var by_key_values := GuardFormScript.writes_by_key(base_writes)
	_check(by_key_values.size() == 2 and int(by_key_values["state_u16:0:7"]) == 1313 and int(by_key_values["global_u8:0:2341"]) == 0, "writes_by_key() reduces writes to key -> value")

	# tool_seeded_preset() shape.
	var preset := GuardFormScript.tool_seeded_preset("tool-seeded", composed)
	_check(str(preset.preset_id) == "tool-seeded" and str(preset.kind) == "tool_seeded_analysis" and preset.writes == composed, "tool_seeded_preset carries the composed writes under the tool_seeded_analysis kind")
	_check((preset.expected_branch_ids as Array).is_empty(), "tool_seeded_preset carries no expected branch ids")

	# guard_result: no synthetic branch_if_not_true bytecode is built here.
	# Per the spec's fallback, guard_result is exercised against the tracked
	# D05 caller in tools/content_suite/validators/validate_catalog_group_routes.gd
	# instead, where the archive is open.
	print("PASS: guard_result is exercised against the tracked D05 caller in the original validator (no synthetic bytecode fixture exists yet)")

	get_tree().quit(1 if _failed else 0)
