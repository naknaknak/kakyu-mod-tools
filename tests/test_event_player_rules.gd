extends "res://tests/test_case.gd"

## TD-11 unit 1: synthetic coverage for the pure functions moved out of
## `tools/content_suite/apps/event_player.gd` into `KakyuEventPlayerRules`,
## `KakyuEventPlayerEventB03` and `KakyuEventPlayerEventB14`. No original
## data, no dialogue - every input here is hand-built.


func _ready() -> void:
	_test_parse_offset()
	_test_matches_branch_row()
	_test_matches_write_row()
	_test_is_state_u16_ref()
	_test_nested_trace_at()
	_test_catalog_list_text()
	_test_is_headless_display()
	_test_eventd01_background_specification()
	_test_eventd05_background_specification()
	_test_promise_option_route_state()
	get_tree().quit(1 if _failed else 0)


func _test_parse_offset() -> void:
	var decimal := KakyuEventPlayerRules.parse_offset("100")
	_check(decimal.get("ok", false) and int(decimal.value) == 100, "parse_offset reads a plain decimal value")
	var hex := KakyuEventPlayerRules.parse_offset("0x1A")
	_check(hex.get("ok", false) and int(hex.value) == 0x1A, "parse_offset reads a 0x-prefixed hexadecimal value")
	var junk := KakyuEventPlayerRules.parse_offset("not-a-number")
	_check(not junk.get("ok", true), "parse_offset rejects junk text")
	var empty := KakyuEventPlayerRules.parse_offset("   ")
	_check(not empty.get("ok", true), "parse_offset rejects an empty/blank value")


func _test_matches_branch_row() -> void:
	var literal_row := {"command_id": 0x0B, "branch_target": 0x20, "condition_ast": {"type": "literal", "value": 1}}
	_check(
		KakyuEventPlayerRules.matches_branch_row(literal_row, "literal", -1, "", 1, 0x20),
		"matches_branch_row accepts a hand-built literal branch row"
	)
	_check(
		not KakyuEventPlayerRules.matches_branch_row(literal_row, "literal", -1, "", 2, 0x20),
		"matches_branch_row rejects a mismatched literal value"
	)
	var binary_row := {
		"command_id": 0x0B, "branch_target": 0x30,
		"condition_ast": {
			"type": "binary", "op": "equal",
			"lhs": {"type": "state_ref", "storage": "state_u16", "index": {"type": "literal", "value": 21}},
			"rhs": {"type": "literal", "value": 0},
		},
	}
	_check(
		KakyuEventPlayerRules.matches_branch_row(binary_row, "binary", 21, "equal", 0, 0x30),
		"matches_branch_row accepts a hand-built binary state comparison row"
	)
	_check(
		not KakyuEventPlayerRules.matches_branch_row(binary_row, "binary", 21, "equal", 0, 0x31),
		"matches_branch_row rejects a mismatched branch target"
	)


func _test_matches_write_row() -> void:
	var state_ref_row := {
		"write_storage": "state_u16", "write_start": 21, "write_count": 1,
		"write_expressions": [{"ast": {"type": "state_ref", "storage": "state_u16", "index": {"type": "literal", "value": 18}}}],
	}
	_check(
		KakyuEventPlayerRules.matches_write_row(state_ref_row, 21, "state_ref", 18, 0),
		"matches_write_row accepts a hand-built state-to-state write row"
	)
	var literal_row := {
		"write_storage": "state_u16", "write_start": 13, "write_count": 1,
		"write_expressions": [{"ast": {"type": "literal", "value": 0xFFFF}}],
	}
	_check(
		KakyuEventPlayerRules.matches_write_row(literal_row, 13, "literal", -1, 0xFFFF),
		"matches_write_row accepts a hand-built literal write row"
	)
	_check(
		not KakyuEventPlayerRules.matches_write_row(literal_row, 13, "literal", -1, 0),
		"matches_write_row rejects a mismatched literal value"
	)


func _test_is_state_u16_ref() -> void:
	var ast := {"type": "state_ref", "storage": "state_u16", "index": {"type": "literal", "value": 7}}
	_check(KakyuEventPlayerRules.is_state_u16_ref(ast, 7), "is_state_u16_ref accepts a hand-built matching reference")
	_check(not KakyuEventPlayerRules.is_state_u16_ref(ast, 8), "is_state_u16_ref rejects a mismatched index")
	_check(
		not KakyuEventPlayerRules.is_state_u16_ref({"type": "literal", "value": 7}, 7),
		"is_state_u16_ref rejects a non-state-ref ast node"
	)


func _test_nested_trace_at() -> void:
	var trace: Array = [{"source_entry": "X.MES", "source_offset": 10, "value": 1}]
	var found := KakyuEventPlayerRules.nested_trace_at(trace, "X.MES", 10)
	_check(int(found.get("value", -1)) == 1, "nested_trace_at finds the record at its exact source entry and offset")
	_check(KakyuEventPlayerRules.nested_trace_at(trace, "X.MES", 11).is_empty(), "nested_trace_at returns empty for an unmatched offset")
	_check(KakyuEventPlayerRules.nested_trace_at(trace, "Y.MES", 10).is_empty(), "nested_trace_at returns empty for an unmatched source entry")


func _test_catalog_list_text() -> void:
	_check(KakyuEventPlayerRules.catalog_list_text([]) == "not cataloged", "catalog_list_text names an empty list as not cataloged")
	_check(KakyuEventPlayerRules.catalog_list_text(["a", "b"]) == "a, b", "catalog_list_text joins a populated list")


func _test_is_headless_display() -> void:
	_check(KakyuEventPlayerRules.is_headless_display(), "is_headless_display is true under the headless test runner")


func _test_eventd01_background_specification() -> void:
	var before600 := KakyuEventPlayerRules.eventd01_background_specification(0)
	_check(
		str(before600.get("resource", "")) == "D01Z.MMO" and int(before600.get("source_offset", -1)) == 0x01AF,
		"eventd01_background_specification before 0600 returns D01Z.MMO at 0x01AF"
	)
	var evening := KakyuEventPlayerRules.eventd01_background_specification(1700)
	_check(
		str(evening.get("resource", "")) == "D01Y.MMO" and int(evening.get("source_offset", -1)) == 0x020C,
		"eventd01_background_specification at 1700 returns D01Y.MMO at 0x020C"
	)
	var night := KakyuEventPlayerRules.eventd01_background_specification(2000)
	_check(
		str(night.get("resource", "")) == "D01Z.MMO" and int(night.get("source_offset", -1)) == 0x021F,
		"eventd01_background_specification at 2000 returns D01Z.MMO at 0x021F"
	)


func _test_eventd05_background_specification() -> void:
	var before600 := KakyuEventPlayerRules.eventd05_background_specification(0)
	_check(
		str(before600.get("resource", "")) == "D05Z.MMO" and int(before600.get("source_offset", -1)) == 0x01BD,
		"eventd05_background_specification before 0600 returns D05Z.MMO at 0x01BD"
	)
	var morning := KakyuEventPlayerRules.eventd05_background_specification(600)
	_check(
		str(morning.get("resource", "")) == "D05X.MMO" and int(morning.get("source_offset", -1)) == 0x01DC,
		"eventd05_background_specification at 0600 returns D05X.MMO at 0x01DC"
	)
	var night := KakyuEventPlayerRules.eventd05_background_specification(2000)
	_check(
		str(night.get("resource", "")) == "D05Z.MMO" and int(night.get("source_offset", -1)) == 0x022D,
		"eventd05_background_specification at 2000 returns D05Z.MMO at 0x022D"
	)


func _test_promise_option_route_state() -> void:
	_check(
		KakyuEventPlayerRules.promise_option_route_state(8, "A_PROMIS.MES", 0, 0) == "entry_gate",
		"promise_option_route_state opens the entry gate for an option inside PROMISE_A_EVENING_GATE_OPTIONS"
	)
	_check(
		KakyuEventPlayerRules.promise_option_route_state(1, "A_PROMIS.MES", 5, 0) == "allowed",
		"promise_option_route_state allows an unrejected location for an option outside PROMISE_A_EVENING_GATE_OPTIONS"
	)
	_check(
		KakyuEventPlayerRules.promise_option_route_state(1, "A_PROMIS.MES", 0, 0) == "rejected",
		"promise_option_route_state rejects a location on that option's rejection list"
	)


