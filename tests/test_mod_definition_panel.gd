extends "res://tests/test_case.gd"

## `tools/content_suite/mod_definition_panel.gd`, its mounting and the three
## Callables in `tools/content_suite/apps/mes_editor.gd` (mod event
## definition unit D): a MES Editor with a named workspace active exercises
## the Definitions tab end to end (New event, New override, Validate, Save,
## Remove, Export set..., Import set...); a second MES Editor with no
## workspace shows every action but Refresh disabled.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const MesEditorScene := preload("res://tools/content_suite/apps/mes_editor.tscn")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")

const TEST_ROOT := "user://mod_definition_panel_test"
const TARGET_ID := "ai.school.gate.09.1"


func _ready() -> void:
	_cleanup()
	var source_root := TEST_ROOT + "/ELFIMAGE"
	var workspace_root := TEST_ROOT + "/mod_workspace"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	SyntheticArc.write_arc(source_root + "/mes.arc", [{"name": "TEST.MES", "data": PackedByteArray([1, 2, 3])}])
	var source_mes_sha := FileAccess.get_sha256(source_root + "/mes.arc")

	var workspace := ContentWorkspaceScript.new()
	_check(
		workspace.create(workspace_root, source_root, _project_document("moddefpanel.test", source_mes_sha)).get("ok", false),
		"a named workspace for the Definitions panel is created empty"
	)
	workspace.close()

	# No active workspace: every action but Refresh stays disabled.
	var idle_editor: Control = MesEditorScene.instantiate()
	idle_editor.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("idle_path_history.cfg")))
	add_child(idle_editor)
	await get_tree().process_frame
	var idle_panel: Control = idle_editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Definitions")
	_check(idle_panel != null, "the MES Editor mounts a Definitions tab")
	_check(
		not (idle_panel.get_node("%RefreshButton") as Button).disabled
		and (idle_panel.get_node("%NewEventButton") as Button).disabled
		and (idle_panel.get_node("%NewOverrideButton") as Button).disabled
		and (idle_panel.get_node("%ValidateButton") as Button).disabled
		and (idle_panel.get_node("%SaveButton") as Button).disabled
		and (idle_panel.get_node("%RemoveButton") as Button).disabled
		and (idle_panel.get_node("%ImportSetButton") as Button).disabled
		and (idle_panel.get_node("%ExportSetButton") as Button).disabled,
		"without an active workspace, every Definitions action but Refresh is disabled"
	)
	_check(
		not str((idle_panel.get_node("%DefinitionSummary") as RichTextLabel).text).is_empty(),
		"the Definitions summary states why the panel is inactive"
	)
	var analysis_tabs: TabContainer = idle_editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs")
	_check(
		analysis_tabs.get_tab_title(analysis_tabs.get_tab_idx_from_control(idle_panel)) == "Definitions",
		"the Definitions tab is titled Definitions"
	)
	idle_editor.queue_free()
	await get_tree().process_frame

	# An active named workspace.
	var editor: Control = MesEditorScene.instantiate()
	editor.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("path_history.cfg")))
	add_child(editor)
	await get_tree().process_frame
	editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root,
	]))
	var panel: Control = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Definitions")
	var mod_id_edit := panel.get_node("%ModIdEdit") as LineEdit
	var target_id_edit := panel.get_node("%TargetIdEdit") as LineEdit
	var definition_text := panel.get_node("%DefinitionText") as TextEdit
	var definition_tree := panel.get_node("%DefinitionTree") as Tree
	var summary := panel.get_node("%DefinitionSummary") as RichTextLabel
	var replace_on_import := panel.get_node("%ReplaceOnImport") as CheckButton

	_check(
		not (panel.get_node("%NewEventButton") as Button).disabled and mod_id_edit.editable,
		"an active workspace enables the Definitions actions and the empty-workspace mod id field"
	)
	var derived_mod_id := mod_id_edit.text
	_check(not derived_mod_id.is_empty(), "the panel prefills a derived mod id for the empty workspace")

	var views := panel.get_node("%DefinitionViews") as TabContainer
	var form := panel.get_node("%DefinitionForm") as Control
	_check(views.get_tab_title(0) == "Form" and views.get_tab_title(1) == "JSON", "the definition views are titled Form and JSON")

	panel.call("_on_new_event_pressed")
	_check(views.current_tab == 0, "New event lands on the Form tab with the template")
	panel.call("_on_validate_pressed")
	_check(
		str(summary.text).begins_with("text_empty"),
		"New event's untouched template fails Validate with text_empty"
	)

	var dialogue_list: KakyuModDefinitionRowList = form.get("_dialogue_list")
	var dialogue_row: HFlowContainer = dialogue_list.get_rows()[0]
	(dialogue_row.get_meta("text_edit") as TextEdit).text = "A short invented line."
	panel.call("_on_validate_pressed")
	_check(str(summary.text).begins_with("ok"), "editing the line text in the form and pressing Validate succeeds (the form was serialized)")

	views.current_tab = 1
	_check(
		str(definition_text.text).contains("A short invented line."),
		"switching to JSON shows the serialized text"
	)

	var choice_fixture := FileAccess.get_file_as_string(
		"res://config/contracts/mod_event_definition_v1/valid/new_event_choice.json"
	)
	var text_before_choice_paste := definition_text.text
	definition_text.text = choice_fixture
	views.current_tab = 0
	_check(
		views.current_tab == 1 and str(summary.text).contains("choice"),
		"pasting JSON with a choice and switching to Form stays on JSON with the reason"
	)
	definition_text.text = text_before_choice_paste
	views.current_tab = 0
	_check(views.current_tab == 0, "switching back to Form succeeds for the covered document")

	panel.call("_on_save_pressed")
	_check(
		str(summary.text).begins_with("Saved mod.%s.new_event_1" % derived_mod_id),
		"Save from the Form tab saves the serialized document"
	)
	var reopened_after_new_event := ContentWorkspaceScript.new()
	_check(reopened_after_new_event.open(workspace_root, source_root).get("ok", false), "workspace reopens after the new_event save")
	var snapshot_after_new_event := reopened_after_new_event.get_snapshot()
	_check(
		int(snapshot_after_new_event.definition_count) == 1 and str(snapshot_after_new_event.mod_id) == derived_mod_id,
		"the workspace snapshot reflects definition_count 1 and the saved mod_id"
	)
	reopened_after_new_event.close()
	_check(not mod_id_edit.editable, "the mod id field is no longer editable once the workspace holds a definition")
	_check(
		definition_tree.get_root() != null and definition_tree.get_root().get_first_child() != null
		and str(definition_tree.get_root().get_first_child().get_text(0)) == "mod.%s.new_event_1" % derived_mod_id,
		"the tree lists the saved new_event id"
	)

	var new_event_id := "mod.%s.new_event_1" % derived_mod_id
	definition_tree.get_root().get_first_child().select(0)
	panel.call("_on_tree_item_selected")
	_check(
		_parse(definition_text.text).dialogue[0].text == "A short invented line.",
		"selecting the row shows the stored document text"
	)

	var manifest_sha_before_bad_save := FileAccess.get_sha256(workspace_root + "/manifest.json")
	var tampered_document := _parse(definition_text.text)
	tampered_document.dialogue[0].text = "Hello {Name}."
	views.current_tab = 1
	definition_text.text = JSON.stringify(tampered_document, "  ") + "\n"
	panel.call("_on_save_pressed")
	_check(
		str(summary.text).contains("bad_placeholder"),
		"Save refuses a document with an unsupported placeholder, reporting bad_placeholder"
	)
	_check(
		FileAccess.get_sha256(workspace_root + "/manifest.json") == manifest_sha_before_bad_save,
		"a refused Save leaves the manifest byte-identical"
	)

	# New override.
	var target_res_path := "res://config/event_definitions/v4/%s.json" % TARGET_ID
	var expected_target_sha := _gdscript_document_sha256_lf(target_res_path)
	var python_target_sha := _python_document_sha256(ProjectSettings.globalize_path(target_res_path))
	_check(not expected_target_sha.is_empty() and expected_target_sha == python_target_sha, "the GDScript and Python document_sha256 of the tracked v4 target agree")

	target_id_edit.text = TARGET_ID
	panel.call("_on_new_override_pressed")
	var override_document := _parse(definition_text.text)
	_check(
		str(override_document.target.document_sha256) == expected_target_sha,
		"New override's target.document_sha256 equals the tracked v4 document's CRLF-normalized SHA-256"
	)
	panel.call("_on_validate_pressed")
	_check(str(summary.text).begins_with("ok"), "New override validates unmodified")
	panel.call("_on_save_pressed")
	_check(str(summary.text).begins_with("Saved mod.%s.override_" % derived_mod_id), "Save reports the saved override id")
	var reopened_after_override := ContentWorkspaceScript.new()
	_check(reopened_after_override.open(workspace_root, source_root).get("ok", false), "workspace reopens after the override save")
	_check(int(reopened_after_override.get_snapshot().definition_count) == 2, "the workspace now holds two definitions")
	reopened_after_override.close()

	# Export set...
	var export_path := ProjectSettings.globalize_path(TEST_ROOT + "/exported_set.json")
	panel.call("_on_export_set_path_selected", export_path)
	_check(FileAccess.file_exists(export_path), "Export set... writes a definition set file")
	var exported_verdict := _python_validate_set(export_path)
	_check(
		exported_verdict.get("ok", false) and int(exported_verdict.get("definition_count", 0)) == 2,
		"the exported set validates with the Python tool and names two definitions"
	)

	# Remove the override.
	var override_id := "mod.%s.override_%s" % [derived_mod_id, TARGET_ID.replace(".", "_")]
	_select_tree_row(definition_tree, override_id)
	panel.call("_on_tree_item_selected")
	panel.call("_on_remove_pressed")
	_check(str(summary.text).begins_with("Removed %s" % override_id), "Remove reports the removed override id")
	var reopened_after_remove := ContentWorkspaceScript.new()
	_check(reopened_after_remove.open(workspace_root, source_root).get("ok", false), "workspace reopens after the removal")
	_check(int(reopened_after_remove.get_snapshot().definition_count) == 1, "removing the override leaves one definition")
	reopened_after_remove.close()

	# Import set... of the exported file with Replace existing off.
	replace_on_import.button_pressed = false
	panel.call("_on_import_set_path_selected", export_path)
	_check(
		str(summary.text).contains("unchanged 1") and str(summary.text).contains("added 1"),
		"importing the exported set without Replace reports one unchanged and one added definition"
	)
	var reopened_after_import := ContentWorkspaceScript.new()
	_check(reopened_after_import.open(workspace_root, source_root).get("ok", false), "workspace reopens after the import")
	_check(int(reopened_after_import.get_snapshot().definition_count) == 2, "the import restores both definitions")
	reopened_after_import.close()

	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(_controls_fit(panel), "the Definitions panel's controls fit at 1024x640")
	var analysis_tabs_active: TabContainer = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs")
	_check(
		analysis_tabs_active.get_tab_title(analysis_tabs_active.get_tab_idx_from_control(panel)) == "Definitions",
		"the active editor's Definitions tab is titled Definitions"
	)

	editor.queue_free()
	await get_tree().process_frame
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _controls_fit(panel: Control) -> bool:
	var layout: Control = panel.get("_layout")
	return Rect2(Vector2.ZERO, panel.size).encloses(layout.get_rect()) and layout.get_rect().size.y >= layout.get_combined_minimum_size().y


func _select_tree_row(tree: Tree, definition_id: String) -> void:
	var root := tree.get_root()
	if root == null:
		return
	var item := root.get_first_child()
	while item != null:
		if str(item.get_metadata(0)) == definition_id:
			item.select(0)
			return
		item = item.get_next()


func _parse(text: String) -> Dictionary:
	# JSON.parse_string returns every JSON number as a float; the contract's
	# strict integer fields need the whole-number floats folded back to int
	# before this round-trips through the Python validator.
	return TestHelpers.intify(JSON.parse_string(text))


func _gdscript_document_sha256_lf(res_path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(res_path)
	var normalized := PackedByteArray()
	normalized.resize(bytes.size())
	var write_index := 0
	var index := 0
	while index < bytes.size():
		if bytes[index] == 0x0D and index + 1 < bytes.size() and bytes[index + 1] == 0x0A:
			normalized[write_index] = 0x0A
			write_index += 1
			index += 2
		else:
			normalized[write_index] = bytes[index]
			write_index += 1
			index += 1
	normalized.resize(write_index)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(normalized)
	return context.finish().hex_encode()


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


func _python_validate_set(absolute_path: String) -> Dictionary:
	var runtime := preload("res://tools/content_suite/python_runtime.gd").resolve("tools/mod_definition_set.py")
	if not runtime.get("ok", false):
		return {"ok": false, "error": str(runtime.get("error", "python runtime unavailable"))}
	var output: Array = []
	var exit_code := OS.execute(str(runtime.python), PackedStringArray([
		"-B", str(runtime.script), "validate", absolute_path,
		"--names", ProjectSettings.globalize_path("res://config/contracts/event_names_v1"),
		"--definitions-dir", ProjectSettings.globalize_path("res://config/event_definitions/v4"),
	]), output, true, false)
	var joined := ""
	for chunk in output:
		joined += str(chunk)
	var last_line := ""
	for line in joined.split("\n"):
		if not str(line).strip_edges().is_empty():
			last_line = str(line).strip_edges()
	var parsed := JSON.new()
	if exit_code != 0 and last_line.is_empty():
		return {"ok": false, "error": "python validate failed: %s" % joined}
	if parsed.parse(last_line) != OK or not parsed.data is Dictionary:
		return {"ok": false, "error": "python validate produced no verdict: %s" % joined}
	return parsed.data


func _project_document(project_id: String, mes_sha: String) -> Dictionary:
	var archives: Array = [{"archive": "mes.arc", "sha256": mes_sha, "required": true}]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": project_id,
		"project_version": "0.1.0",
		"display_name": "Mod Definition Panel Test",
		"project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"],
		"compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)
