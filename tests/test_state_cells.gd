extends "res://tests/test_case.gd"

## `content_core/state_cells.gd`, the Godot port of `tools/state_cells.py`
## over the tracked table `config/contracts/state_cells_v1/state_cells.json`
## (MW-13, unit A).

const StateCells := preload("res://content_core/state_cells.gd")


func _ready() -> void:
	# Named cells.
	_check(StateCells.classify("state_u16", 0, 4, []) == "weekday", "state_u16[4] is weekday")
	_check(StateCells.classify("state_u16", 0, 7, []) == "date", "state_u16[7] is date")
	_check(StateCells.classify("state_u16", 0, 19, []) == "clock", "state_u16[19] is clock")
	_check(StateCells.classify("state_u16", 0, 0, []) == "clock_part", "state_u16[0] is clock_part")
	_check(StateCells.classify("state_u16", 0, 1, []) == "clock_part", "state_u16[1] is clock_part")
	_check(StateCells.classify("state_u16", 0, 21, []) == "choice_result", "state_u16[21] is choice_result")
	_check(StateCells.classify("state_u16", 0, 18, []) == "map_poll_result", "state_u16[18] is map_poll_result")

	var affection_cells := {
		200: "reiko", 201: "miko", 202: "mizuho", 203: "mayumi", 204: "ryoko",
		205: "tina", 206: "nana", 207: "miyuki", 208: "ai", 209: "sizuka",
		210: "mahoko", 211: "minatu", 212: "maki",
	}
	for index in affection_cells:
		var expected_heroine: String = affection_cells[index]
		_check(
			StateCells.classify("banked_u16", 0, index, []) == "affection",
			"banked_u16[%d] is affection" % index,
		)
		_check(
			StateCells.heroine("banked_u16", 0, index) == expected_heroine,
			"banked_u16[%d]'s heroine is %s" % [index, expected_heroine],
		)
	_check(affection_cells.size() == 13, "thirteen affection cells are checked")
	var heroines := StateCells.heroines()
	_check(heroines.size() == 13, "heroines() lists thirteen names")
	var expected_order := PackedStringArray([
		"reiko", "miko", "mizuho", "mayumi", "ryoko", "tina", "nana",
		"miyuki", "ai", "sizuka", "mahoko", "minatu", "maki",
	])
	_check(heroines == expected_order, "heroines() lists the thirteen names in table order")

	_check(StateCells.classify("banked_u16", 0, 213, []) == "unnamed", "banked_u16[213] is unnamed, not affection")
	_check(StateCells.heroine("banked_u16", 0, 213) == "", "banked_u16[213] has no heroine")

	# The global_u8 rule.
	_check(StateCells.classify("global_u8", 0, 900, []) == "counter", "global_u8 with no observations is counter")
	_check(StateCells.classify("global_u8", 0, 900, [0, 1]) == "flag", "global_u8 observed only as 0 and 1 is flag")
	_check(StateCells.classify("global_u8", 0, 900, [0, 2]) == "counter", "global_u8 observed as 0 and 2 is counter")
	_check(StateCells.classify("global_u8", 0, 900, [1, 1, 0]) == "flag", "global_u8 observed as 1 and 0 repeated is flag")

	# The other storages fall back to unnamed.
	_check(StateCells.classify("state_u16", 0, 999, []) == "unnamed", "an unnamed state_u16 cell is unnamed")
	_check(StateCells.classify("banked_u16", 0, 999, []) == "unnamed", "an unnamed banked_u16 cell is unnamed")
	_check(StateCells.classify("banked_u8", 0, 5, []) == "unnamed", "banked_u8 is unnamed")
	_check(StateCells.classify("global_i32", 0, 5, []) == "unnamed", "global_i32 is unnamed")

	# An unknown storage.
	_check(StateCells.classify("no_such_storage", 0, 0, []) == "", "an unknown storage classifies as an empty string")

	# The fingerprint check against the tracked value.
	_check(StateCells.fingerprint_ok(), "the loaded table's fingerprint matches the tracked cells_fingerprint")
	_check(
		StateCells.computed_fingerprint() == StateCells.stored_fingerprint(),
		"the computed fingerprint equals the stored one",
	)

	get_tree().quit(1 if _failed else 0)
