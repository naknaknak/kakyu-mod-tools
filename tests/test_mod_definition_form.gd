extends "res://tests/test_case.gd"

## `tools/content_suite/mod_definition_form.gd`, the structured form view of
## a `kakyu_mod_event_definition/v1` document (MW-13, unit B): the covered
## fixtures round-trip, the uncovered fixtures are refused with a reason,
## and editing the row lists updates the assembled document and the
## cell-class labels (section B3).

const FormScript := preload("res://tools/content_suite/mod_definition_form.gd")
const StateCells := preload("res://content_core/state_cells.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")
const FIXTURE_DIR := "res://config/contracts/mod_event_definition_v1/valid/"
const TARGET_ID := "ai.school.gate.09.1"


func _ready() -> void:
	var covered := ["new_event_plain", "override_conditions", "override_disable"]
	for fixture_name in covered:
		var document := _load_fixture(fixture_name)
		var form: Control = _new_form()
		var outcome: Dictionary = form.load_document(document)
		_check(outcome.get("ok", false), "%s: load_document is ok" % fixture_name)
		var round_tripped: Dictionary = form.to_document()
		_check(
			round_tripped == document,
			"%s: to_document(load_document(d)) equals the fixture" % fixture_name,
		)
		form.queue_free()

	# A document the form has not loaded a terminal from (a fresh form)
	# names the single terminal by kind: "map" for return_to_map.
	var fresh_form: Control = _new_form()
	var fresh_document: Dictionary = fresh_form.to_document()
	_check(
		fresh_document.terminals.has("map") and fresh_document.results.result_default.terminal == "map",
		"a new document (no loaded terminal) gets the default key map",
	)
	fresh_form.queue_free()

	var uncovered := {
		"new_event_choice": "choice",
		"new_event_conditional_results": "result",
		"override_results": "replace_result",
	}
	for fixture_name in uncovered:
		var document := _load_fixture(fixture_name)
		var form: Control = _new_form()
		var outcome: Dictionary = form.load_document(document)
		_check(not outcome.get("ok", false), "%s: load_document is not ok" % fixture_name)
		var reason := str(outcome.get("reason", ""))
		_check(
			reason.contains(str(uncovered[fixture_name])),
			"%s: reason %s names the uncovered feature" % [fixture_name, reason],
		)
		form.queue_free()

	# Editing checks, on a fresh new_event covered document.
	var form: Control = _new_form()
	var base_document := _load_fixture("new_event_plain")
	_check(form.load_document(base_document).get("ok", false), "the editing form loads new_event_plain")

	form._title_en_edit.text = "A changed title"
	var after_title_change: Dictionary = form.to_document()
	_check(after_title_change.display.title_en == "A changed title", "changing the title reflects in to_document")

	var conditions_before: int = (form._conditions_list as Node).get("_entries").size()
	form._conditions_list.add_row({"type": "weekday_equals", "weekday": 5})
	var after_condition: Dictionary = form.to_document()
	_check(
		after_condition.conditions.size() == conditions_before + 1
		and after_condition.conditions[after_condition.conditions.size() - 1].type == "weekday_equals"
		and int(after_condition.conditions[after_condition.conditions.size() - 1].weekday) == 5,
		"adding a weekday_equals condition appears in to_document",
	)

	var first_write_row: HFlowContainer = form._after_list.add_row({
		"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 300, "value": 1,
	})
	_check(
		str((first_write_row.get_meta("cell_class_label") as Label).text).contains("flag"),
		"a lone write of 0/1 on global_u8[300] labels the row flag",
	)
	var after_first_write: Dictionary = form.to_document()
	_check(
		_last_after_entry(after_first_write).cell_class == "flag",
		"the assembled document's row cell_class is flag",
	)

	var second_write_row: HFlowContainer = form._after_list.add_row({
		"type": "write_legacy_value", "storage": "global_u8", "bank": 0, "index": 300, "value": 5,
	})
	_check(
		str((first_write_row.get_meta("cell_class_label") as Label).text).contains("counter")
		and str((second_write_row.get_meta("cell_class_label") as Label).text).contains("counter"),
		"a second write with a different value relabels both rows counter",
	)
	var after_second_write: Dictionary = form.to_document()
	var global_u8_300_classes := []
	for entry in after_second_write.after:
		if str(entry.get("storage", "")) == "global_u8" and int(entry.get("index", -1)) == 300:
			global_u8_300_classes.append(str(entry.cell_class))
	_check(
		global_u8_300_classes == ["counter", "counter"],
		"both assembled rows for global_u8[300] carry cell_class counter",
	)

	var legacy_cell_row: HFlowContainer = form._conditions_list.add_row({
		"type": "legacy_cell", "storage": "banked_u16", "bank": 0, "index": 204, "operator": "equal", "value": 10,
	})
	_check(
		str((legacy_cell_row.get_meta("cell_class_label") as Label).text).contains("affection"),
		"a legacy_cell condition on banked_u16[204] labels the row affection",
	)
	var after_legacy_cell: Dictionary = form.to_document()
	_check(
		_last_condition_entry(after_legacy_cell).cell_class == "affection",
		"the assembled document's legacy_cell row cell_class is affection",
	)

	form._after_list.add_row({
		"type": "add_legacy_value", "storage": "global_u8", "bank": 0, "index": 400, "delta": 3,
	})
	var after_add_no_min: Dictionary = form.to_document()
	_check(
		not _last_after_entry(after_add_no_min).has("min"),
		"an add_legacy_value with min unset omits min",
	)

	form._after_list.add_row({"type": "consume_time", "minutes": 30})
	var after_consume_time: Dictionary = form.to_document()
	_check(
		_last_after_entry(after_consume_time).cell_class == "clock",
		"consume_time writes cell_class clock",
	)

	var dialogue_text := "Line one\nLine two {name}"
	form._dialogue_list.add_row({"kind": "line", "text": dialogue_text})
	var after_dialogue: Dictionary = form.to_document()
	var last_dialogue: Dictionary = after_dialogue.dialogue[after_dialogue.dialogue.size() - 1]
	_check(
		str(last_dialogue.get("text", "")) == dialogue_text,
		"a dialogue line with U+000A and {name} round-trips",
	)

	var changed_fired := [false]
	form.changed.connect(func() -> void: changed_fired[0] = true)
	form._conditions_list.add_row({"type": "always"})
	_check(changed_fired[0], "the changed signal fires on an edit")
	form.queue_free()

	# Override "Rebase".
	var override_form: Control = _new_form()
	var override_document := {
		"schema_version": "kakyu_mod_event_definition/v1",
		"contract_fingerprint": "self",
		"cells_fingerprint": "self",
		"kind": "override",
		"mod": {"id": "samplemod", "revision": 1},
		"id": "mod.samplemod.override_rebase_test",
		"target": {
			"id": TARGET_ID,
			"contract": "kakyu_event_definition/v4",
			"document_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
		},
		"operations": [{"op": "disable"}],
	}
	_check(override_form.load_document(override_document).get("ok", false), "the rebase form loads a synthetic override")
	override_form.call("_on_rebase_pressed")
	var target_path := "res://config/event_definitions/v4/%s.json" % TARGET_ID
	var expected_sha := FormScript.document_sha256_lf(target_path)
	var python_sha := _python_document_sha256(ProjectSettings.globalize_path(target_path))
	_check(not expected_sha.is_empty() and expected_sha == python_sha, "the GDScript and Python document_sha256 of the tracked v4 target agree")
	_check(
		str(override_form._target_sha_label.text) == expected_sha,
		"Rebase recomputes the hash of the tracked v4 document",
	)
	override_form.queue_free()

	get_tree().quit(1 if _failed else 0)


func _new_form() -> Control:
	var form: Control = FormScript.new()
	add_child(form)
	form.set_heroines(StateCells.heroines())
	return form


func _load_fixture(name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(FIXTURE_DIR + name + ".json")
	return TestHelpers.intify(JSON.parse_string(text))


func _last_after_entry(document: Dictionary) -> Dictionary:
	var after: Array = document.after
	return after[after.size() - 1]


func _last_condition_entry(document: Dictionary) -> Dictionary:
	var conditions: Array = document.conditions
	return conditions[conditions.size() - 1]


func _python_document_sha256(absolute_path: String) -> String:
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/validate_mod_event_definition.py")
	if not runtime.get("ok", false):
		return ""
	var output: Array = []
	var exit_code := OS.execute(str(runtime.python), PackedStringArray([
		"-B", "-c",
		"import sys; sys.path.insert(0, sys.argv[1]); import validate_mod_event_definition as m; print(m.document_sha256(sys.argv[2]))",
		ProjectSettings.globalize_path("res://tools"), absolute_path,
	]), output, true, false)
	if exit_code != 0:
		return ""
	var joined := ""
	for chunk in output:
		joined += str(chunk)
	for line in joined.split("\n"):
		var trimmed := str(line).strip_edges()
		if trimmed.length() == 64:
			return trimmed
	return ""
