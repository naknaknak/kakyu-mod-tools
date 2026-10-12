class_name KakyuMenuFlowVariants
extends RefCounted

## EP-12 gallery (2026-10-04, the all-menus unit): the pure part of
## `cli/measure_menu_flow.gd` that turns what the measurer found into the
## route's v14 variants. The measurer runs the scene (it needs the archive);
## this helper holds the rules, so they are proved on synthetic measurements
## (`tests/test_menu_flow_variants.gd`).
##
## A route's own path is the **default** variant: the first option at every
## question the scene asks, the DATE5 cells (all 1) of a recap scene. What the
## scene can also do is a variant (`docs/spec/tech/content_tools.md`, "Variant
## `answers` and `message_counts`"):
##
##   - every other combination of the scene's question options that reaches the
##     route's own terminal (a two-question scene: each answered combination);
##   - a recap scene's second path (the four state cells all 2), with its own
##     message count.
##
## **Stop rule.** A path whose terminal record differs from the route's, or
## which does not run to a terminal, cannot be a variant; it is returned in
## `not_declared`, which the measurer writes into the route's `unresolved`
## list and its report.
##
## **Named cell-write variants** (EP-12 H, 2026-10-04): the recap scene's
## `hotel-path` is one instance of a general kind - a variant that is the
## default path with a set of `global_u8` cells written another value
## (`cell_variant`). The recollection ladders of the room declare
## `no-recollection` (every gate flag of the ladder 0) the same way; a measured
## path that ends elsewhere is refused by the same stop rule.
##
## A *leaf* is one measured path: `{answers: [{boundary_offset, result_value}]
## in the order the scene asked them, stop: String, messages: int, terminal:
## "status@offset"}`.


## `option-2`, `option-2-1`: the leaf's values in the order the scene asked.
static func variant_id(leaf_answers: Array) -> String:
	var parts := PackedStringArray()
	for untyped_answer in leaf_answers:
		var answer: Dictionary = untyped_answer
		parts.append(str(int(answer.result_value)))
	return "option-" + "-".join(parts)


static func _value_at(answers: Array, boundary: int) -> int:
	for untyped_answer in answers:
		var answer: Dictionary = untyped_answer
		if int(answer.boundary_offset) == boundary:
			return int(answer.result_value)
	return -1


## A variant's `answers`: only what differs from the default path - an answer
## at a boundary the default path answers differently, or at a boundary the
## default path never reaches (the question exists only on this path). The
## default answers stay the hop's own, so an unchanged question needs no entry.
static func variant_answers(hop_id: String, default_answers: Array, leaf_answers: Array) -> Array:
	var out := []
	for untyped_answer in leaf_answers:
		var answer: Dictionary = untyped_answer
		var boundary := int(answer.boundary_offset)
		if _value_at(default_answers, boundary) != int(answer.result_value):
			out.append({"hop_id": hop_id, "boundary_offset": boundary, "result_value": int(answer.result_value)})
	return out


## Boundaries a leaf answers that the default path does not ask at all.
static func variant_only_boundaries(default_answers: Array, leaf_answers: Array) -> Array:
	var out := []
	for untyped_answer in leaf_answers:
		var answer: Dictionary = untyped_answer
		if _value_at(default_answers, int(answer.boundary_offset)) == -1:
			out.append(int(answer.boundary_offset))
	return out


## Boundaries the default path asks that this leaf's path never reaches.
static func skipped_boundaries(default_answers: Array, leaf_answers: Array) -> Array:
	var out := []
	for untyped_answer in default_answers:
		var answer: Dictionary = untyped_answer
		if _value_at(leaf_answers, int(answer.boundary_offset)) == -1:
			out.append(int(answer.boundary_offset))
	return out


static func _same_answers(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for untyped_answer in a:
		var answer: Dictionary = untyped_answer
		if _value_at(b, int(answer.boundary_offset)) != int(answer.result_value):
			return false
	return true


## The reason a measured path cannot be a variant, or "" when it can: it must
## run to a terminal (`stop` empty) and end at the route's own terminal.
static func refusal(stop: String, terminal: String, default_terminal: String) -> String:
	if stop != "":
		return "does not run to its return (%s)" % stop
	if terminal != default_terminal:
		return "ends at %s, not the route's own %s" % [terminal, default_terminal]
	return ""


## A cell-write variant: the default path with each of `cells` (`global_u8`)
## written `value`. `measured` is `{stop, messages, terminal}` of the run made
## under those writes. Returns `{variant: {...}}` when the path ends at the
## route's own terminal and `{not_declared: {...}}` (the stop rule) when it does
## not. The variant carries `message_counts` only when it plays another number
## of messages at `hop_id` than the default.
static func cell_variant(hop_id: String, variant_id: String, label: String, cells: Array, value: int,
		default_messages: int, default_terminal: String, measured: Dictionary) -> Dictionary:
	var reason := refusal(str(measured.stop), str(measured.terminal), default_terminal)
	if reason != "":
		return {"not_declared": {"variant_id": variant_id, "label": label, "reason": reason,
			"messages": int(measured.messages)}}
	var writes := []
	for cell in cells:
		writes.append({"storage": "global_u8", "bank": 0, "index": int(cell), "value": value})
	var variant := {"variant_id": variant_id, "writes": writes, "expected_state": []}
	if int(measured.messages) != default_messages:
		variant["message_counts"] = {hop_id: int(measured.messages)}
	return {"variant": variant}


## Everything the measurer declares for one scene.
##
## `default_answers` are the hop's own answers (`[{boundary_offset,
## result_value}]`), `default_messages` and `default_terminal` what the default
## path played and where it ended. `leaves` are every measured answer
## combination (the default's own leaf may be among them and is skipped).
## `recap_alt` is `{cells: [int], stop, messages, terminal}` for a recap
## scene's second path, `{}` for any other scene. `cell_paths` (EP-12 H) are
## further named cell-write variants, `[{variant_id, label, cells: [int], value,
## stop, messages, terminal}]`, declared after the recap's.
##
## Returns `{variants: [variant dicts, default first, in measured order],
## not_declared: [{variant_id, label, reason}], variant_only_questions:
## [boundary], skipped_questions: [boundary]}`; `variants` is empty when the
## scene has nothing but its default path. A declared variant is
## `{variant_id, writes, expected_state}` plus `answers` when its answers
## differ from the default's and `message_counts` when it plays a different
## number of messages at `hop_id`.
static func assemble(hop_id: String, default_answers: Array, default_messages: int, default_terminal: String,
		leaves: Array, recap_alt: Dictionary, cell_paths: Array = []) -> Dictionary:
	var declared := []
	var not_declared := []
	var variant_only := []
	var skipped := []
	var used_ids := {"default": true}
	for untyped_leaf in leaves:
		var leaf: Dictionary = untyped_leaf
		var leaf_answers: Array = leaf.answers
		if _same_answers(leaf_answers, default_answers):
			continue
		var id := variant_id(leaf_answers)
		var reason := refusal(str(leaf.stop), str(leaf.terminal), default_terminal)
		if reason != "":
			not_declared.append({"variant_id": id, "label": "answers " + id.trim_prefix("option-"), "reason": reason,
				"messages": int(leaf.messages)})
			continue
		assert(not used_ids.has(id), "two measured paths share the variant id %s" % id)
		used_ids[id] = true
		var variant := {"variant_id": id, "writes": [], "expected_state": [],
			"answers": variant_answers(hop_id, default_answers, leaf_answers)}
		if int(leaf.messages) != default_messages:
			variant["message_counts"] = {hop_id: int(leaf.messages)}
		declared.append(variant)
		for boundary in variant_only_boundaries(default_answers, leaf_answers):
			if not variant_only.has(boundary):
				variant_only.append(boundary)
		for boundary in skipped_boundaries(default_answers, leaf_answers):
			if not skipped.has(boundary):
				skipped.append(boundary)
	var named_paths := []
	if not recap_alt.is_empty():
		named_paths.append({"variant_id": "hotel-path", "label": "the hotel path of the recap (cells all 2)",
			"cells": recap_alt.cells, "value": 2, "stop": recap_alt.stop, "messages": recap_alt.messages,
			"terminal": recap_alt.terminal})
	named_paths.append_array(cell_paths)
	for untyped_path in named_paths:
		var path: Dictionary = untyped_path
		assert(not used_ids.has(str(path.variant_id)), "two variants share the id %s" % str(path.variant_id))
		used_ids[str(path.variant_id)] = true
		var made := cell_variant(hop_id, str(path.variant_id), str(path.label), path.cells, int(path.value),
			default_messages, default_terminal, path)
		if made.has("not_declared"):
			not_declared.append(made.not_declared)
		else:
			declared.append(made.variant)
	var variants := []
	if not declared.is_empty():
		variants.append({"variant_id": "default", "writes": [], "expected_state": []})
		variants.append_array(declared)
	return {"variants": variants, "not_declared": not_declared,
		"variant_only_questions": variant_only, "skipped_questions": skipped}


## The route's `unresolved` lines for what could not be declared.
static func unresolved_lines(not_declared: Array) -> Array:
	var out := []
	for untyped_entry in not_declared:
		var entry: Dictionary = untyped_entry
		out.append("The path %s plays %d messages and %s; not declared: a variant must end at the route's own terminal." % [
			str(entry.label), int(entry.messages), str(entry.reason)])
	return out
