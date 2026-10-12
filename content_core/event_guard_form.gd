class_name KakyuEventGuardForm
extends RefCounted

## EP-10 unit 3: the guard-derived starting-state form. Owner's direction of
## 2026-09-20: "the bounds of each value the branch needs can be user input,
## like the Analysis sandbox" - a saved preset is only a saved input, and a
## route can be run from any starting state the guard accepts. This class is
## pure and static; it reads a v4 event definition's typed guard
## (`guard.conjuncts`) and turns it into editable fields, composes a
## candidate state's writes, and runs the caller's guard record once to
## check whether a candidate state passes.

const StateCellsScript := preload("res://content_core/state_cells.gd")
const EventRunnerScript := preload("res://content_core/mes_event_runner.gd")


## One entry per distinct cell the conjuncts name, in first-appearance
## order. `{"fields": [...], "readonly": [...]}`. A `choice` or
## `mes_expression` conjunct is shown read-only instead of as a field.
static func fields(conjuncts: Array, table := {}) -> Dictionary:
	var order: Array[String] = []
	var by_key: Dictionary = {}
	var observed: Dictionary = {}
	var readonly: Array[Dictionary] = []
	# First pass: collect every literal value named for a cell, so the
	# storage-wide classifier (`global_u8` flag vs. counter) sees the whole
	# set of values the guard names, not just the first conjunct's.
	for conjunct_value in conjuncts:
		var conjunct: Dictionary = conjunct_value
		var cell := _cell_of(conjunct)
		if cell.is_empty():
			continue
		var cell_key := key(str(cell.storage), int(cell.bank), int(cell.index))
		if not observed.has(cell_key):
			observed[cell_key] = []
		if conjunct.has("value"):
			(observed[cell_key] as Array).append(int(conjunct.value))
	for conjunct_value in conjuncts:
		var conjunct: Dictionary = conjunct_value
		var kind := str(conjunct.get("kind", ""))
		if kind == "choice":
			readonly.append({"kind": "choice", "text": "choice %s %s" % [str(conjunct.get("op", "")), str(conjunct.get("value", ""))]})
			continue
		if kind == "mes_expression":
			var ast: Dictionary = conjunct.get("ast", {})
			var offset := int((ast.get("source", {}) as Dictionary).get("offset", -1))
			readonly.append({"kind": "mes_expression", "text": "expression at %d" % offset})
			continue
		var cell := _cell_of(conjunct)
		if cell.is_empty():
			continue
		var cell_key := key(str(cell.storage), int(cell.bank), int(cell.index))
		var storage := str(cell.storage)
		var bank := int(cell.bank)
		var index := int(cell.index)
		if not by_key.has(cell_key):
			var default_range := _default_range(storage)
			var cell_class := StateCellsScript.classify(storage, bank, index, observed.get(cell_key, []), table)
			var heroine := StateCellsScript.heroine(storage, bank, index, table)
			by_key[cell_key] = {
				"key": cell_key, "storage": storage, "bank": bank, "index": index, "kind": kind,
				"label": _label(kind, storage, index, cell_class, heroine),
				"cell_class": cell_class, "heroine": heroine,
				"min": default_range[0], "max": default_range[1], "fixed": null,
				"excluded": [], "notes": [],
			}
			order.append(cell_key)
		var field: Dictionary = by_key[cell_key]
		var op := str(conjunct.get("op", ""))
		var value := int(conjunct.get("value", 0))
		if op == "greater_than":
			field.min = maxi(int(field.min), value + 1)
		elif op == "less_than":
			field.max = mini(int(field.max), value - 1)
		elif op == "equal":
			field.fixed = value
		elif op == "not_equal":
			(field.excluded as Array).append(value)
		(field.notes as Array).append("%s %s %d" % [kind, op, value])
	var result_fields: Array[Dictionary] = []
	for order_key in order:
		result_fields.append(by_key[order_key])
	return {"fields": result_fields, "readonly": readonly}


## `(storage, bank, index)` -> a stable string key, shared by `fields`,
## `writes`, `event_catalog.gd`'s tool-preset validation, the Event Player
## and the group-route validator, so all of them mean the same thing by
## "the same cell".
static func key(storage: String, bank: int, index: int) -> String:
	return "%s:%d:%d" % [storage, bank, index]


## `writes` (any array of `{"storage","bank","index","value",...}` records)
## reduced to `key(storage, bank, index) -> value`, last write wins.
static func writes_by_key(writes_list: Array) -> Dictionary:
	var result := {}
	for write_value in writes_list:
		var write: Dictionary = write_value
		result[key(str(write.get("storage", "")), int(write.get("bank", 0)), int(write.get("index", -1)))] = int(write.get("value", 0))
	return result


## The base writes (the selected preset's) with each field's value
## overriding by `(storage, bank, index)` key, appended when new.
static func writes(fields_list: Array, values: Dictionary, base_writes: Array) -> Array:
	var result: Array = []
	var index_by_key := {}
	for base_value in base_writes:
		var base: Dictionary = base_value
		var base_key := key(str(base.get("storage", "")), int(base.get("bank", 0)), int(base.get("index", -1)))
		index_by_key[base_key] = result.size()
		result.append({
			"storage": str(base.get("storage", "")), "bank": int(base.get("bank", 0)),
			"index": int(base.get("index", -1)), "value": int(base.get("value", 0)),
			"evidence_level": "tool_seeded",
		})
	for field_value in fields_list:
		var field: Dictionary = field_value
		var field_key := str(field.get("key", ""))
		if not values.has(field_key):
			continue
		var entry := {
			"storage": str(field.get("storage", "")), "bank": int(field.get("bank", 0)),
			"index": int(field.get("index", -1)), "value": int(values[field_key]), "evidence_level": "tool_seeded",
		}
		if index_by_key.has(field_key):
			result[index_by_key[field_key]] = entry
		else:
			index_by_key[field_key] = result.size()
			result.append(entry)
	return result


## Runs one instruction of the caller's guard record on a duplicate of
## `state` and reports whether it passes.
static func guard_result(code: PackedByteArray, code_size: int, guard_offset: int, state: KakyuMesSandboxState) -> Dictionary:
	var run := EventRunnerScript.new().run(code, guard_offset, state.duplicate_state(), code_size, 1)
	var trace: Array = run.get("trace", [])
	if trace.size() != 1:
		return {"ok": false, "passes": false, "condition_value": -1, "next_offset": -1, "error": str(run.get("error", "The guard could not be evaluated."))}
	var record: Dictionary = trace[0]
	var condition_value := int(record.get("condition_value", -1))
	return {
		"ok": true, "passes": condition_value == 1, "condition_value": condition_value,
		"next_offset": int(record.get("next_offset", -1)), "error": "",
	}


static func tool_seeded_preset(preset_id: String, writes_list: Array) -> Dictionary:
	return {
		"preset_id": preset_id, "label": "Tool-seeded state", "kind": "tool_seeded_analysis",
		"writes": writes_list, "expected_branch_ids": [],
		"notes": "Starting state entered in the guard form; labelled tool-seeded, not a captured game state.",
	}


static func _cell_of(conjunct: Dictionary) -> Dictionary:
	var kind := str(conjunct.get("kind", ""))
	if kind == "date":
		return {"storage": "state_u16", "bank": 0, "index": 7}
	if kind == "clock":
		return {"storage": "state_u16", "bank": 0, "index": 19}
	if kind == "weekday":
		return {"storage": "state_u16", "bank": 0, "index": 4}
	if kind == "cell":
		return {"storage": str(conjunct.get("storage", "")), "bank": int(conjunct.get("bank", 0)), "index": int(conjunct.get("index", -1))}
	return {}


static func _default_range(storage: String) -> Array:
	if storage in ["global_u8", "banked_u8"]:
		return [0, 255]
	return [0, 65535]


static func _label(kind: String, storage: String, index: int, cell_class: String, heroine: String) -> String:
	if not heroine.is_empty():
		return "%s affection (%s[%d])" % [heroine.capitalize(), storage, index]
	if kind in ["date", "clock", "weekday"]:
		return "%s (%s[%d])" % [kind, storage, index]
	return "%s %s[%d]" % [cell_class, storage, index]
