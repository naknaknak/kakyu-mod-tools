extends "res://tests/test_case.gd"

## EP-12 gallery (2026-10-04, the all-menus unit): the rules that turn what
## `tools/content_suite/cli/measure_menu_flow.gd` measured into a route's v14
## variants (`tools/content_suite/menu_flow_variants.gd`), on synthetic
## measurements - no archive. The measurer's own run needs the original
## archive and is covered by the archive-tier group checks of the profiles it
## writes.

const Variants := preload("res://tools/content_suite/menu_flow_variants.gd")

const HOP := "h2_scene"
const RETURN := "script_return@500"


func _answer(boundary: int, value: int) -> Dictionary:
	return {"boundary_offset": boundary, "result_value": value}


func _leaf(answers: Array, messages: int, terminal: String = RETURN, stop: String = "") -> Dictionary:
	return {"answers": answers, "stop": stop, "messages": messages, "terminal": terminal}


func _ids(variants: Array) -> Array:
	var out := []
	for variant in variants:
		out.append(str(variant.variant_id))
	return out


func _ready() -> void:
	# A scene with no question and no recap has nothing but its default path.
	var none := Variants.assemble(HOP, [], 9, RETURN, [], {})
	_check(none.variants.is_empty() and none.not_declared.is_empty(), "a scene with one path declares no variant")

	# One two-option question (the J08 shape): option 2 plays the same count, so no `message_counts`.
	var one := Variants.assemble(HOP, [_answer(353, 1)], 9, RETURN, [
		_leaf([_answer(353, 1)], 9), _leaf([_answer(353, 2)], 9)], {})
	_check(_ids(one.variants) == ["default", "option-2"], "one question: the default and option-2 (the default's own leaf is not repeated)")
	var option2: Dictionary = one.variants[1]
	_check(option2.answers == [{"hop_id": HOP, "boundary_offset": 353, "result_value": 2}], "the variant's answer names the hop, the boundary and the value")
	_check(not option2.has("message_counts"), "an option that plays the default's count carries no message_counts")
	_check(option2.writes == [] and option2.expected_state == [], "an option variant writes nothing")
	_check(one.variants[0] == {"variant_id": "default", "writes": [], "expected_state": []}, "the default variant is the empty one")

	# A different count is the variant's own.
	var counted := Variants.assemble(HOP, [_answer(353, 1)], 9, RETURN, [_leaf([_answer(353, 1)], 9), _leaf([_answer(353, 2)], 11)], {})
	_check(counted.variants[1].message_counts == {HOP: 11}, "an option that plays another count carries it")

	# Three options: two variants, in option order.
	var three := Variants.assemble(HOP, [_answer(353, 1)], 9, RETURN, [
		_leaf([_answer(353, 1)], 9), _leaf([_answer(353, 2)], 9), _leaf([_answer(353, 3)], 12)], {})
	_check(_ids(three.variants) == ["default", "option-2", "option-3"], "three options give two variants in option order")

	# Two questions (the I02 / L11 shape): every answered combination is a variant; its answers
	# list only what differs from the default path.
	var q1 := 100
	var q2 := 200
	var two := Variants.assemble(HOP, [_answer(q1, 1), _answer(q2, 1)], 20, RETURN, [
		_leaf([_answer(q1, 1), _answer(q2, 1)], 20), _leaf([_answer(q1, 1), _answer(q2, 2)], 21),
		_leaf([_answer(q1, 2), _answer(q2, 1)], 20), _leaf([_answer(q1, 2), _answer(q2, 2)], 22)], {})
	_check(_ids(two.variants) == ["default", "option-1-2", "option-2-1", "option-2-2"], "two two-option questions give three variants")
	_check(two.variants[1].answers == [{"hop_id": HOP, "boundary_offset": q2, "result_value": 2}], "a combination changing one question answers only that one")
	_check(two.variants[3].answers.size() == 2 and two.variants[3].message_counts == {HOP: 22}, "the all-changed combination answers both and carries its count")
	_check(two.variant_only_questions.is_empty() and two.skipped_questions.is_empty(), "a path walking the same questions reports no variant-only or skipped question")

	# A path ending at another terminal, or not returning, is not a variant (the stop rule).
	var stopped := Variants.assemble(HOP, [_answer(353, 1)], 9, RETURN, [
		_leaf([_answer(353, 1)], 9), _leaf([_answer(353, 2)], 4, "script_handoff_boundary@40"),
		_leaf([_answer(353, 3)], 6, RETURN, "step_limit")], {})
	_check(stopped.variants.is_empty(), "a scene whose only other paths end elsewhere declares no variant")
	_check(stopped.not_declared.size() == 2 and str(stopped.not_declared[0].reason).contains("script_handoff_boundary@40"),
		"the other terminal is named in the refusal")
	_check(str(stopped.not_declared[1].reason).contains("step_limit"), "a path that does not return names its stop")
	var lines := Variants.unresolved_lines(stopped.not_declared)
	_check(lines.size() == 2 and str(lines[0]).contains("not declared") and str(lines[0]).contains("4 messages"), "each refusal becomes one unresolved line")

	# A refused path does not hide the declarable ones.
	var mixed := Variants.assemble(HOP, [_answer(353, 1)], 9, RETURN, [
		_leaf([_answer(353, 1)], 9), _leaf([_answer(353, 2)], 9), _leaf([_answer(353, 3)], 4, "script_handoff_boundary@40")], {})
	_check(_ids(mixed.variants) == ["default", "option-2"] and mixed.not_declared.size() == 1, "a declarable option stays declared beside a refused one")

	# A recap scene's second path (the SCENE_J14 shape).
	var recap := Variants.assemble(HOP, [], 32, RETURN, [], {"cells": [2708, 2709, 2710, 2711], "stop": "", "messages": 36, "terminal": RETURN})
	_check(_ids(recap.variants) == ["default", "hotel-path"], "a recap scene declares the hotel path")
	var hotel: Dictionary = recap.variants[1]
	_check(hotel.writes.size() == 4 and hotel.writes[0] == {"storage": "global_u8", "bank": 0, "index": 2708, "value": 2}, "the hotel path writes each cell 2")
	_check(hotel.message_counts == {HOP: 36} and not hotel.has("answers"), "the hotel path carries its own count and no answers")
	var recap_same := Variants.assemble(HOP, [], 32, RETURN, [], {"cells": [1], "stop": "", "messages": 32, "terminal": RETURN})
	_check(not recap_same.variants[1].has("message_counts"), "a hotel path playing the default count carries none")
	var recap_other := Variants.assemble(HOP, [], 32, RETURN, [], {"cells": [1], "stop": "", "messages": 10, "terminal": "script_return@99"})
	_check(recap_other.variants.is_empty() and recap_other.not_declared[0].variant_id == "hotel-path", "a hotel path ending elsewhere is refused")

	# EP-12 H (2026-10-04): a named cell-write variant is the same rule as the recap's hotel
	# path with its own id and value (the room's `no-recollection`: every gate cell 0).
	var ladder := {"variant_id": "no-recollection", "label": "no recollection (every gate flag 0)",
		"cells": [1110, 1111, 2561], "value": 0, "stop": "", "messages": 9, "terminal": RETURN}
	var cells := Variants.assemble(HOP, [], 917, RETURN, [], {}, [ladder])
	_check(_ids(cells.variants) == ["default", "no-recollection"], "a cell path declares its named variant after the default")
	var none_set: Dictionary = cells.variants[1]
	_check(none_set.writes == [{"storage": "global_u8", "bank": 0, "index": 1110, "value": 0},
		{"storage": "global_u8", "bank": 0, "index": 1111, "value": 0}, {"storage": "global_u8", "bank": 0, "index": 2561, "value": 0}],
		"the variant writes each cell the path's value")
	_check(none_set.message_counts == {HOP: 9} and not none_set.has("answers") and none_set.expected_state == [], "it carries its own count and no answers")
	var same_count := Variants.assemble(HOP, [], 9, RETURN, [], {}, [ladder])
	_check(not same_count.variants[1].has("message_counts"), "a cell path playing the default count carries none")
	var elsewhere := ladder.duplicate()
	elsewhere["terminal"] = "script_return@77"
	var refused := Variants.assemble(HOP, [], 917, RETURN, [], {}, [elsewhere])
	_check(refused.variants.is_empty() and refused.not_declared.size() == 1 and refused.not_declared[0].variant_id == "no-recollection"
		and str(refused.not_declared[0].reason).contains("script_return@77"), "a cell path ending elsewhere is refused and named")
	var both := Variants.assemble(HOP, [], 32, RETURN, [], {"cells": [2708], "stop": "", "messages": 36, "terminal": RETURN}, [ladder])
	_check(_ids(both.variants) == ["default", "hotel-path", "no-recollection"], "the recap path and a named cell path coexist, the recap's first")
	var single := Variants.cell_variant(HOP, "x", "x", [5], 0, 4, RETURN, {"stop": "", "messages": 4, "terminal": RETURN})
	_check(single.has("variant") and not single.variant.has("message_counts") and single.variant.writes[0].value == 0, "cell_variant builds one variant")

	# Advisor note (d): a question that exists only on a variant's path is a variant-supplied
	# answer (the default path never asks it) and is reported; a default question the variant's
	# path never reaches is reported as skipped.
	var only := Variants.assemble(HOP, [_answer(q1, 1)], 10, RETURN, [
		_leaf([_answer(q1, 1)], 10), _leaf([_answer(q1, 2), _answer(q2, 1)], 14)], {})
	_check(only.variants.size() == 2 and only.variants[1].answers.size() == 2, "a variant-only question is answered by the variant")
	_check(only.variant_only_questions == [q2], "the variant-only question is reported")
	var skipped := Variants.assemble(HOP, [_answer(q1, 1), _answer(q2, 1)], 10, RETURN, [
		_leaf([_answer(q1, 1), _answer(q2, 1)], 10), _leaf([_answer(q1, 2)], 7)], {})
	_check(skipped.skipped_questions == [q2], "a default question the variant never reaches is reported as skipped")

	# Helpers.
	_check(Variants.variant_id([_answer(1, 2)]) == "option-2" and Variants.variant_id([_answer(1, 2), _answer(2, 1)]) == "option-2-1", "variant ids spell the answered values in order")
	_check(Variants.refusal("", RETURN, RETURN) == "" and Variants.refusal("x", RETURN, RETURN) != "", "refusal: empty for a returning path, named otherwise")

	get_tree().quit(1 if _failed else 0)
