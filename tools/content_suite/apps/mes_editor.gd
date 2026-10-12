extends Control

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const InstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const TextCacheScript := preload("res://content_core/mes_text_cache.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const MesTextPatcherScript := preload("res://content_core/mes_text_patcher.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const MesEditorRunRequestScript := preload("res://content_core/mes_editor_run_request.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const MesTranslationCatalogScript := preload("res://content_core/mes_translation_catalog.gd")
const MesTextOutputPolicyScript := preload("res://content_core/mes_text_output_policy.gd")
const MesSemanticDiffScript := preload("res://content_core/mes_semantic_diff.gd")
const AuthoringPanelScript := preload("res://tools/content_suite/mes_authoring_panel.gd")
const AuthoringSessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const DefinitionPanelScript := preload("res://tools/content_suite/mod_definition_panel.gd")
const ModDefinitionBindingScript := preload("res://tools/content_suite/mod_definition_binding.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const HEX_PREVIEW_BYTES := 256
const DISASSEMBLY_LIMIT := 500
const CFG_NODE_LIMIT := 120
const CFG_EXPANSION_DEPTH := 2
const CFG_EXPANDED_REGION_LIMIT := 8
const NAVIGATION_HISTORY_LIMIT := 128

@onready var archive_label: Label = %ArchiveLabel
@onready var filter_edit: LineEdit = %FilterEdit
@onready var entry_tree: Tree = %EntryTree
@onready var address_tree: Tree = %AddressTree
@onready var details: RichTextLabel = %Details
@onready var hex_preview: RichTextLabel = %HexPreview
@onready var analysis_tabs: TabContainer = %AnalysisTabs
@onready var message_search_edit: LineEdit = %MessageSearchEdit
@onready var message_tree: Tree = %MessageTree
@onready var message_edit: LineEdit = %MessageEdit
@onready var message_stage_button: Button = %MessageStageButton
@onready var message_revert_button: Button = %MessageRevertButton
@onready var overlay_detach_button: Button = %OverlayDetachButton
@onready var overlay_save_button: Button = %OverlaySaveButton
@onready var hot_reload_overlay_button: Button = %HotReloadOverlay
@onready var clear_overlay_button: Button = %ClearOverlay
@onready var run_event_player_button: Button = %RunEventPlayer
@onready var binary_patch_label: Label = %BinaryPatchLabel
@onready var binary_overlay_save_button: Button = %BinaryOverlaySaveButton
@onready var binary_arc_export_button: Button = %BinaryArcExportButton
@onready var pending_label: Label = %PendingLabel
@onready var catalog_target_locale: LineEdit = %CatalogTargetLocale
@onready var catalog_translator_id: LineEdit = %CatalogTranslatorId
@onready var catalog_export_button: Button = %CatalogExportButton
@onready var catalog_update_button: Button = %CatalogUpdateButton
@onready var catalog_import_button: Button = %CatalogImportButton
@onready var reference_tabs: TabContainer = %References
@onready var code_reference_tree: Tree = %CodeReferenceTree
@onready var state_reference_tree: Tree = %StateReferenceTree
@onready var resource_reference_tree: Tree = %ResourceReferenceTree
@onready var cfg_back_button: Button = %CfgBackButton
@onready var cfg_forward_button: Button = %CfgForwardButton
@onready var cfg_show_confirmed: CheckButton = %CfgShowConfirmed
@onready var cfg_show_structural: CheckButton = %CfgShowStructural
@onready var cfg_show_stops: CheckButton = %CfgShowStops
@onready var cfg_focus_button: Button = %CfgFocusButton
@onready var cfg_export_button: Button = %CfgExportButton
@onready var cfg_summary: Label = %CfgSummary
@onready var cfg_graph: GraphEdit = %CfgGraph
@onready var status_label: Label = %StatusLabel
@onready var open_dialog: FileDialog = %OpenDialog
@onready var text_cache_dialog: FileDialog = %TextCacheDialog
@onready var overlay_load_dialog: FileDialog = %OverlayLoadDialog
@onready var overlay_save_dialog: FileDialog = %OverlaySaveDialog
@onready var binary_overlay_save_dialog: FileDialog = %BinaryOverlaySaveDialog
@onready var binary_arc_export_dialog: FileDialog = %BinaryArcExportDialog
@onready var cfg_export_dialog: FileDialog = %CfgExportDialog
@onready var catalog_export_dialog: FileDialog = %CatalogExportDialog
@onready var catalog_update_source_dialog: FileDialog = %CatalogUpdateSourceDialog
@onready var catalog_update_output_dialog: FileDialog = %CatalogUpdateOutputDialog
@onready var catalog_import_dialog: FileDialog = %CatalogImportDialog

var _reader := ArcReaderScript.new()
var _path_history := ToolPathHistoryScript.new()
var _launch_context := ContentLaunchContextScript.new()
var _parser := MesContainerScript.new()
var _decoder := InstructionDecoderScript.new()
var _analysis_builder := MesAnalysisScript.new()
var _text_cache := TextCacheScript.new()
var _overlay_package := OverlayPackageScript.new()
var _resolver := ContentResolverScript.new()
var _mes_text_patcher := MesTextPatcherScript.new()
var _cp932 := Cp932CodecScript.new()
var _run_request_builder := MesEditorRunRequestScript.new()
var _translation_catalog := MesTranslationCatalogScript.new()
var _text_output_policy := MesTextOutputPolicyScript.new()
var _pending_catalog_update: Dictionary = {}
var _mes_entries: Array[Dictionary] = []
var _archive_sha256 := ""
var _document: Dictionary = {}
var _analysis: Dictionary = {}
var _selected_entry_name := ""
var _text_cache_root := ""
var _text_messages: Dictionary = {}
var _overlay_root := ""
var _overlay_manifest_sha256 := ""
var _overlay_messages: Dictionary = {}
var _pending_text_edits_by_entry: Dictionary = {}
var _selected_message_offset := -1
var _navigation_history: Array[int] = []
var _navigation_index := -1
var _history_navigation_active := false
var _cfg_graph_data: Dictionary = {}
var _cfg_selected_node_id := ""
var _cfg_selecting_programmatically := false
var _entry_selection_restore_active := false
var _entry_selection_restore_pending := false
var _authoring_proof_path := ""
var _definitions_panel: Control


func _ready() -> void:
	ToolWindowProfileScript.apply(get_window())
	entry_tree.set_column_title(0, "MES entry")
	entry_tree.set_column_title(1, "Bytes")
	entry_tree.set_column_expand(0, true)
	entry_tree.set_column_expand(1, false)
	entry_tree.set_column_custom_minimum_width(1, 72)
	address_tree.set_column_title(0, "Address")
	address_tree.set_column_title(1, "Code offset")
	address_tree.set_column_title(2, "Bytes")
	address_tree.set_column_expand(0, false)
	address_tree.set_column_expand(1, false)
	address_tree.set_column_expand(2, false)
	message_tree.set_column_title(0, "Offset")
	message_tree.set_column_title(1, "Region")
	message_tree.set_column_title(2, "Text / CP932 diagnostic")
	message_tree.set_column_expand(0, false)
	message_tree.set_column_expand(1, false)
	message_tree.set_column_expand(2, true)
	message_tree.set_column_custom_minimum_width(0, 88)
	message_tree.set_column_custom_minimum_width(1, 92)
	code_reference_tree.set_column_title(0, "Source")
	code_reference_tree.set_column_title(1, "Reference")
	code_reference_tree.set_column_title(2, "Target")
	code_reference_tree.set_column_title(3, "Boundary")
	state_reference_tree.set_column_title(0, "Source")
	state_reference_tree.set_column_title(1, "Access")
	state_reference_tree.set_column_title(2, "Numeric storage")
	state_reference_tree.set_column_title(3, "Index / count")
	reference_tabs.set_tab_title(reference_tabs.get_tab_idx_from_control(code_reference_tree), "Code")
	reference_tabs.set_tab_title(reference_tabs.get_tab_idx_from_control(state_reference_tree), "State")
	reference_tabs.set_tab_title(reference_tabs.get_tab_idx_from_control(resource_reference_tree), "Resources")
	resource_reference_tree.set_column_title(0, "Source")
	resource_reference_tree.set_column_title(1, "Kind")
	resource_reference_tree.set_column_title(2, "Resource")
	resource_reference_tree.set_column_title(3, "Archives / boundary / native")
	_path_history.apply_source_dialog(open_dialog)
	var arguments := OS.get_cmdline_user_args()
	_apply_startup_arguments(arguments)
	var authoring := AuthoringPanelScript.new()
	authoring.name = "Authoring"
	authoring.context_provider = _authoring_context
	authoring.publish_output = _publish_authored_bundle
	%AnalysisTabs.add_child(authoring)
	_definitions_panel = DefinitionPanelScript.new()
	_definitions_panel.name = "Definitions"
	_definitions_panel.context_provider = _definitions_context
	_definitions_panel.publish_definitions = _publish_mod_definitions
	_definitions_panel.remove_definition = _remove_mod_definition
	%AnalysisTabs.add_child(_definitions_panel)


func _apply_startup_arguments(arguments: PackedStringArray) -> void:
	var startup := _launch_context.activate(arguments)
	if not startup.ok:
		status_label.text = str(startup.error)
		return
	if not startup.named:
		if not startup.legacy_arguments.is_empty():
			_open_archive(str(startup.legacy_arguments[0]))
		if startup.legacy_arguments.size() >= 2:
			_configure_text_cache(str(startup.legacy_arguments[1]))
		return
	var archive_path := _launch_context.get_preferred_archive_path(["mes.arc"])
	if archive_path.is_empty():
		status_label.text = "Workspace does not contain mes.arc."
		return
	_open_archive(archive_path)
	if _reader.is_open():
		_on_overlay_load_selected(_launch_context.get_workspace_root())
		var selection_path := _launch_context.get_selection_path()
		if not selection_path.is_empty():
			var consumed := _consume_selection(selection_path)
			if not consumed.get("ok", false):
				status_label.text = "Selection rejected: %s" % str(consumed.error)


func _consume_selection(path: String) -> Dictionary:
	if not _launch_context.is_active() or not _reader.is_open():
		return {"ok": false, "error": "A selection requires the named workspace's open ARC."}
	var selection_contract := ContentSelectionScript.new()
	var read_result := selection_contract.read_path(path)
	if not read_result.get("ok", false):
		return {"ok": false, "error": str(read_result.get("error", "Selection could not be read."))}
	var document: Dictionary = read_result.document
	var validated := selection_contract.validate_for_workspace(document, _launch_context.get_snapshot())
	if not validated.get("ok", false):
		return {"ok": false, "error": str(validated.get("error", "Selection was rejected."))}
	var selection: Dictionary = document.selection
	if str(selection.archive).to_lower() != "mes.arc":
		return {"ok": false, "error": "Selection names an archive this MES Editor session did not open."}
	var entry_name := str(selection.entry)
	var entry := _reader.get_entry(entry_name)
	if entry.is_empty() or _reader.get_entry_fingerprint(entry_name) != str(selection.source_entry_sha256):
		return {"ok": false, "error": "Selection names a changed or unknown original entry."}
	filter_edit.text = ""
	_rebuild_entry_tree()
	_load_entry(entry_name)
	return {"ok": true, "entry": entry_name}


func _on_open_pressed() -> void:
	_path_history.apply_source_dialog(open_dialog)
	open_dialog.popup_centered_ratio(0.75)


func _contextual_run_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var catalog := preload("res://content_core/event_catalog.gd").new()
	if not _launch_context.is_active() or not catalog.load_file("res://config/event_catalog/original_events_v1.json").get("ok", false):
		return options
	var catalog_id := str(catalog.get_summary().catalog_id)
	if str(_launch_context.get_snapshot().project.get("event_player", {}).get("catalog_id", "")) != catalog_id:
		return options
	for event in catalog.get_events():
		if str(event.source.callee.entry).to_upper() != _selected_entry_name.to_upper():
			continue
		for preset in event.presets:
			options.append({"mode": "catalog_event", "start_kind": "catalog_preset", "start_value": 0,
				"catalog_id": catalog_id, "event_id": str(event.event_id),
				"preset_id": str(preset.preset_id), "preset_source": "catalog"})
	return options


func _on_run_event_player_pressed() -> void:
	_prepare_selected_run(_selected_run_start())


func _prepare_selected_run(start: Dictionary) -> void:
	if not start.get("ok", false):
		status_label.text = str(start.error)
		return
	if str(_document.get("source", {}).get("resolved_source", "")) != "original_arc":
		status_label.text = "MES Editor Run opens original entries only; the edited entry stays in the editor."
		return
	_publish_and_launch_run(start, {}, "")


func _authoring_context() -> Dictionary:
	if not _launch_context.is_active() or not _reader.is_open() or not _document.get("ok", false):
		return {"ok": false, "error": "Open a named workspace and select an original MES entry."}
	if _pending_count_total() > 0 or _has_unstaged_message_draft():
		return {"ok": false, "error": "Save or revert text drafts before preparing a structural edit."}
	var source_sha := _reader.get_entry_fingerprint(_selected_entry_name)
	if str(_document.entry_sha256) != source_sha:
		return {"ok": false, "error": "This first structural workflow starts from the original entry; an already compiled replacement needs a new source session."}
	var snapshot := _launch_context.get_snapshot()
	var workspace := _launch_context.get_workspace_root()
	if FileAccess.get_sha256(workspace.path_join("manifest.json")) != str(snapshot.manifest_sha256):
		return {"ok": false, "error": "The named workspace changed; Hot Reload before authoring."}
	return {
		"ok": true, "archive_path": _reader.archive_path, "entry": _selected_entry_name,
		"source_sha256": source_sha, "archive_sha256": _archive_sha256,
		"workspace": workspace, "generation_sha256": str(snapshot.generation_sha256),
	}


func _publish_authored_bundle(bundle: Dictionary, expected_context: Dictionary) -> Dictionary:
	if _authoring_context() != expected_context:
		return {"ok": false, "error": "The authoring workspace or selected source changed."}
	var checked := AuthoringSessionScript.read_bundle(str(bundle.get("directory", "")))
	if not checked.get("ok", false) or not checked.has("audit"):
		return {"ok": false, "error": str(checked.get("error", "A compiled authoring bundle is required."))}
	var summary: Dictionary = checked.manifest.summary
	if str(summary.source_entry_sha256) != str(expected_context.source_sha256) or str(summary.source_identity.archive_sha256) != _archive_sha256 or str(summary.source_identity.entry).to_upper() != _selected_entry_name.to_upper():
		return {"ok": false, "error": "The compiled bundle belongs to another original source."}
	var source_check := AuthoringSessionScript.validate_source(checked, _reader.read_entry(_selected_entry_name))
	if not source_check.get("ok", false):
		return source_check
	if source_check.has("points"):
		var text_check := AuthoringSessionScript.BindingScript.map_text(_overlay_messages, source_check)
		if not text_check.get("ok", false):
			return text_check
	var workspace := ContentWorkspaceScript.new()
	var opened := workspace.open(str(expected_context.workspace), _launch_context.get_content_set_root())
	if not opened.get("ok", false) or str(opened.snapshot.generation_sha256) != str(expected_context.generation_sha256):
		workspace.close()
		return {"ok": false, "error": "The workspace generation changed before structural publication."}
	var published := workspace.stage_replacements("mes.arc", {_selected_entry_name: checked.files["output.mes"]}, "remake_only", "cp932")
	workspace.close()
	if not published.get("ok", false):
		return published
	var configured := _configure_loaded_overlay(str(expected_context.workspace))
	if not configured.get("ok", false):
		return {"ok": false, "error": "The compiled MES was published but reopening failed: %s" % str(configured.error)}
	var activated := _activate_loaded_overlay(configured)
	if not activated.get("ok", false):
		return activated
	_authoring_proof_path = str(checked.directory).path_join("semantic.diff.json")
	return {"ok": true, "proof_path": _authoring_proof_path}


func _definitions_context() -> Dictionary:
	if not _launch_context.is_active():
		return {"ok": false, "error": "Open a named workspace to edit its definitions."}
	return {
		"ok": true,
		"workspace": _launch_context.get_workspace_root(),
		"content_set_root": _launch_context.get_content_set_root(),
		"snapshot": _launch_context.get_snapshot(),
	}


func _publish_mod_definitions(documents: Array) -> Dictionary:
	var expected_context := _definitions_context()
	if not expected_context.get("ok", false):
		return expected_context
	var workspace := ContentWorkspaceScript.new()
	var opened := workspace.open(str(expected_context.workspace), _launch_context.get_content_set_root())
	if not opened.get("ok", false) or str(opened.snapshot.generation_sha256) != str(expected_context.snapshot.generation_sha256):
		workspace.close()
		return {"ok": false, "error": "The workspace generation changed; Hot Reload before saving definitions."}
	var staged := workspace.stage_mod_definitions(documents, ModDefinitionBindingScript.validator())
	workspace.close()
	if not staged.get("ok", false):
		return staged
	return _refresh_after_definitions_change(staged)


func _remove_mod_definition(definition_id: String) -> Dictionary:
	var expected_context := _definitions_context()
	if not expected_context.get("ok", false):
		return expected_context
	var workspace := ContentWorkspaceScript.new()
	var opened := workspace.open(str(expected_context.workspace), _launch_context.get_content_set_root())
	if not opened.get("ok", false) or str(opened.snapshot.generation_sha256) != str(expected_context.snapshot.generation_sha256):
		workspace.close()
		return {"ok": false, "error": "The workspace generation changed; Hot Reload before saving definitions."}
	var removed := workspace.remove_mod_definition(definition_id)
	workspace.close()
	if not removed.get("ok", false):
		return removed
	return _refresh_after_definitions_change(removed)


## Shared choreography after `stage_mod_definitions`/`remove_mod_definition`
## publish successfully: refresh the launch context and, when the loaded
## overlay is that same workspace, reopen it so the manifest fingerprint the
## editor holds stays current. Returns `staged_or_removed` on success.
func _refresh_after_definitions_change(staged_or_removed: Dictionary) -> Dictionary:
	var refreshed := _launch_context.refresh()
	if not refreshed.get("ok", false):
		return {"ok": false, "error": "The definitions change was saved, but the workspace could not be refreshed: %s" % str(refreshed.error)}
	if not _overlay_root.is_empty() and _overlay_root.simplify_path().to_lower() == _launch_context.get_workspace_root().simplify_path().to_lower():
		var configured := _configure_loaded_overlay(_overlay_root)
		if not configured.get("ok", false):
			return {"ok": false, "error": "The definitions change was saved, but reopening the loaded overlay failed: %s" % str(configured.error)}
		var activated := _activate_loaded_overlay(configured)
		if not activated.get("ok", false):
			return {"ok": false, "error": "The definitions change was saved, but reopening the loaded overlay failed: %s" % str(activated.error)}
	return staged_or_removed


func _on_catalog_export_pressed() -> void:
	var prepared := _build_selected_translation_catalog()
	if not prepared.get("ok", false):
		status_label.text = str(prepared.error)
		return
	catalog_export_dialog.current_dir = _launch_context.get_workspace_root()
	catalog_export_dialog.current_file = "%s.translation.json" % _selected_entry_name.get_basename().to_lower()
	catalog_export_dialog.popup_centered_ratio(0.75)


func _on_catalog_export_path_selected(path: String) -> void:
	var catalog := _build_selected_translation_catalog()
	if not catalog.get("ok", false):
		status_label.text = str(catalog.error)
		return
	var published := _publish_translation_catalog(path, catalog)
	if published.get("ok", false):
		status_label.text = "Exported %d source-bound translation row(s): %s" % [
			catalog.rows.size(), str(published.path),
		]
	else:
		status_label.text = str(published.error)


func _on_catalog_update_pressed() -> void:
	if _pending_for_selected().is_empty() or _pending_count_total() != _pending_for_selected().size():
		status_label.text = "Catalog Update requires staged edits only in the selected entry."
		return
	catalog_update_source_dialog.current_dir = _launch_context.get_workspace_root()
	catalog_update_source_dialog.popup_centered_ratio(0.75)


func _on_catalog_update_source_selected(path: String) -> void:
	var loaded := _load_translation_catalog(path)
	if not loaded.get("ok", false):
		status_label.text = str(loaded.error)
		return
	var prepared := _prepare_translation_catalog_update(loaded.document)
	if not prepared.get("ok", false):
		status_label.text = str(prepared.error)
		return
	_pending_catalog_update = prepared.catalog
	catalog_update_output_dialog.current_dir = _launch_context.get_workspace_root()
	catalog_update_output_dialog.current_file = "%s.r%d.translation.json" % [
		_selected_entry_name.get_basename().to_lower(),
		int(_pending_catalog_update.catalog.catalog_revision),
	]
	catalog_update_output_dialog.popup_centered_ratio(0.75)


func _on_catalog_update_output_selected(path: String) -> void:
	if _pending_catalog_update.is_empty():
		status_label.text = "Catalog Update has no prepared revision."
		return
	var catalog := _pending_catalog_update.duplicate(true)
	_pending_catalog_update.clear()
	var published := _publish_translation_catalog(path, catalog)
	if published.get("ok", false):
		status_label.text = "Published translation catalog revision %d: %s" % [
			int(catalog.catalog.catalog_revision), str(published.path),
		]
	else:
		status_label.text = str(published.error)


func _on_catalog_import_pressed() -> void:
	if _pending_count_total() > 0 or _has_unstaged_message_draft():
		status_label.text = "Catalog Import requires no pending or unstaged edits."
		return
	catalog_import_dialog.current_dir = _launch_context.get_workspace_root()
	catalog_import_dialog.popup_centered_ratio(0.75)


func _on_catalog_import_selected(path: String) -> void:
	var imported := _import_translation_catalog(path)
	status_label.text = (
		"Imported %d translation(s) as pending UTF-8 edits; use Save all... to publish the overlay." % int(imported.edit_count)
		if imported.get("ok", false) else str(imported.error)
	)


func _build_selected_translation_catalog() -> Dictionary:
	var ready := _translation_catalog_context_ready(false)
	if not ready.get("ok", false):
		return ready
	var metadata := {
		"catalog_id": _translation_catalog_id(), "catalog_revision": 1,
		"source_locale": "ja-JP", "target_locale": catalog_target_locale.text.strip_edges(),
	}
	return _translation_catalog.build(metadata, _translation_source_binding(), [
		_translation_selected_entry(),
	])


func _prepare_translation_catalog_update(catalog: Dictionary) -> Dictionary:
	var ready := _translation_catalog_context_ready(true)
	if not ready.get("ok", false):
		return ready
	var translator_id := catalog_translator_id.text.strip_edges()
	if translator_id.is_empty():
		return {"ok": false, "error": "Enter a lowercase translator ID before Catalog Update."}
	var source_check := _translation_catalog.reconcile(
		catalog, _translation_source_binding(), [_translation_selected_entry()]
	)
	if not source_check.get("ok", false):
		return source_check
	if not source_check.ready:
		return {"ok": false, "error": _translation_diagnostic_summary(source_check)}
	var rows_by_locator := {}
	for value in catalog.rows:
		var row: Dictionary = value
		if str(row.entry).to_upper() != _selected_entry_name.to_upper():
			return {"ok": false, "error": "Selected-entry Catalog Update rejects rows for another MES entry."}
		rows_by_locator[int(row.source_offset)] = row
	var updates: Array = []
	for untyped_offset in _pending_for_selected():
		var offset := int(untyped_offset)
		if not rows_by_locator.has(offset):
			return {"ok": false, "error": "Catalog is missing pending message 0x%X." % offset}
		var row: Dictionary = rows_by_locator[offset]
		var pending: Dictionary = _pending_for_selected()[offset]
		if str(row.raw_sha256) != str(pending.raw_sha256):
			return {"ok": false, "error": "Catalog message 0x%X is stale." % offset}
		updates.append({
			"message_id": str(row.message_id), "state": "draft",
			"text": str(pending.text), "translator_id": translator_id,
			"revision": int(row.translation.revision) + 1,
		})
	var updated := _translation_catalog.apply_updates(
		catalog, updates, int(catalog.catalog.catalog_revision) + 1
	)
	return {"ok": true, "catalog": updated} if updated.get("ok", false) else updated


func _import_translation_catalog(path: String) -> Dictionary:
	var ready := _translation_catalog_context_ready(false)
	if not ready.get("ok", false):
		return ready
	if _pending_count_total() > 0 or _has_unstaged_message_draft():
		return {"ok": false, "error": "Catalog Import requires no pending or unstaged edits."}
	var loaded := _load_translation_catalog(path)
	if not loaded.get("ok", false):
		return loaded
	for value in loaded.document.rows:
		if str(value.entry).to_upper() != _selected_entry_name.to_upper():
			return {"ok": false, "error": "Selected-entry Catalog Import rejects rows for another MES entry."}
	var reconciled := _translation_catalog.reconcile(
		loaded.document, _translation_source_binding(), [_translation_selected_entry()]
	)
	if not reconciled.get("ok", false):
		return reconciled
	if not reconciled.ready:
		return {"ok": false, "error": _translation_diagnostic_summary(reconciled)}
	if int(reconciled.applicable_edit_count) == 0:
		return {"ok": false, "error": "Catalog contains no translated rows to import."}
	var pending := {}
	for edit in reconciled.edits_by_entry.get(_selected_entry_name.to_upper(), []):
		var message := _message_record_at(int(edit.source_offset))
		pending[int(edit.source_offset)] = {
			"source_offset": int(edit.source_offset), "raw_sha256": str(edit.raw_sha256),
			"text": str(edit.text),
			"source_archive_sha256": _archive_sha256,
			"source_entry_sha256": str(_document.get("entry_sha256", "")),
			"native_stream_projection_match": _message_native_projection_matches(message),
		}
	_pending_text_edits_by_entry[_selected_entry_name.to_upper()] = pending
	_rebuild_message_tree()
	_populate_message_edit()
	_refresh_details()
	return {"ok": true, "edit_count": pending.size(), "catalog": loaded.document}


func _load_translation_catalog(path: String) -> Dictionary:
	if not _path_is_inside(path, _launch_context.get_workspace_root()):
		return {"ok": false, "error": "Translation catalogs must be loaded from inside the active workspace."}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		return {"ok": false, "error": "Translation catalog is not a JSON object."}
	var checked := _translation_catalog.validate(value)
	return {"ok": true, "document": value} if checked.get("ok", false) else checked


func _publish_translation_catalog(path: String, catalog: Dictionary) -> Dictionary:
	if path.get_extension().to_lower() != "json":
		return {"ok": false, "error": "Translation catalog output must use .json."}
	if not _path_is_inside(path, _launch_context.get_workspace_root()):
		return {"ok": false, "error": "Translation catalogs must be published inside the active workspace."}
	var checked := _translation_catalog.validate(catalog)
	if not checked.get("ok", false):
		return checked
	var written := _write_new_text_file(path, JSON.stringify(catalog, "", true, true) + "\n")
	if not written.get("ok", false):
		return written
	var reopened := _load_translation_catalog(str(written.path))
	if not reopened.get("ok", false) or str(reopened.document.payload_sha256) != str(catalog.payload_sha256):
		return {
			"ok": false,
			"error": "Published translation catalog failed reopen validation: %s" % str(
				reopened.get("error", "fingerprint changed")
			),
		}
	return written


func _translation_catalog_context_ready(require_pending: bool) -> Dictionary:
	if (
		not _launch_context.is_active() or not _reader.is_open()
		or not _document.get("ok", false) or _selected_entry_name.is_empty()
	):
		return {"ok": false, "error": "Translation Catalog requires a selected parsed MES entry in an active workspace."}
	if str(_document.get("source", {}).get("resolved_source", "")) != "original_arc":
		return {"ok": false, "error": "Translation Catalog v1 requires the selected original MES source."}
	if _has_unstaged_message_draft():
		return {"ok": false, "error": "Stage or discard the current text draft first."}
	if require_pending and _pending_for_selected().is_empty():
		return {"ok": false, "error": "Stage at least one selected-entry translation first."}
	if not require_pending and _pending_count_total() > 0:
		return {"ok": false, "error": "Save or revert pending edits before this Catalog action."}
	return {"ok": true}


func _translation_catalog_id() -> String:
	var project_id := str(_launch_context.get_snapshot().get("project", {}).get("project_id", "workspace"))
	return "%s.translation" % project_id.substr(0, min(project_id.length(), 116))


func _translation_source_binding() -> Dictionary:
	return {
		"archive": "mes.arc", "archive_sha256": _archive_sha256,
		"source_content_set_sha256": str(
			_launch_context.get_snapshot().get("source_content_set", {}).get("fingerprint_sha256", "")
		),
	}


func _translation_selected_entry() -> Dictionary:
	return {
		"entry": _selected_entry_name,
		"entry_sha256": str(_document.get("entry_sha256", "")),
		"messages": _analysis.get("messages", []),
	}


func _translation_diagnostic_summary(result: Dictionary) -> String:
	var counts: Dictionary = result.get("diagnostic_counts", {})
	var parts: Array[String] = []
	for code in [
		"stale_source", "stale_entry", "stale_message", "missing_source_row",
		"missing_catalog_row", "conflicting_row",
	]:
		if int(counts.get(code, 0)) > 0:
			parts.append("%s=%d" % [code, int(counts[code])])
	return "Translation catalog import refused: %s." % ", ".join(parts)


func _path_is_inside(path: String, root: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path).simplify_path().replace("\\", "/")
	var absolute_root := ProjectSettings.globalize_path(root).simplify_path().replace("\\", "/").trim_suffix("/")
	return absolute.to_lower().begins_with(absolute_root.to_lower() + "/")


func _selected_run_start() -> Dictionary:
	if not _document.get("ok", false) or _selected_entry_name.is_empty():
		return {"ok": false, "error": "Select a parsed MES entry before Run."}
	var item := address_tree.get_selected()
	if item == null or not item.get_metadata(0) is Dictionary:
		return {"ok": true, "start_kind": "code_offset", "start_value": 0}
	var range_data: Dictionary = item.get_metadata(0)
	return {
		"ok": true, "start_kind": "code_offset",
		"start_value": int(range_data.get("offset", 0)),
	}


func _publish_and_launch_run(
	start: Dictionary, semantic_diff: Dictionary, proof_path: String
) -> Dictionary:
	var output_path := _next_run_request_path()
	if output_path.is_empty():
		return _run_request_error("MES Editor Run requires an active named workspace.")
	var published := _publish_run_request(
		output_path, str(start.start_kind), int(start.start_value), semantic_diff, start.get("launch", {})
	)
	if not published.get("ok", false):
		return published
	var launch := _build_event_player_run_arguments(str(published.path), proof_path)
	if not launch.get("ok", false):
		return _run_request_error(str(launch.error))
	var pid := OS.create_process(str(launch.executable), launch.arguments)
	if pid <= 0:
		return _run_request_error(
			"Run request was published, but Event Player could not be started: %s" % str(published.path)
		)
	status_label.text = "Started Event Player for %s at 0x%X (PID %d); source ARC remains read-only." % [
		_selected_entry_name, int(start.start_value), pid,
	]
	return {"ok": true, "path": str(published.path), "pid": pid}


func _next_run_request_path() -> String:
	if not _launch_context.is_active():
		return ""
	var base_name := _selected_entry_name.get_basename().to_lower()
	return _launch_context.get_workspace_root().path_join("run_requests").path_join(
		"%s-%d-%d.run.json" % [base_name, OS.get_process_id(), Time.get_ticks_usec()]
	)


func _build_event_player_run_arguments(
	request_path: String, proof_path := ""
) -> Dictionary:
	if not _launch_context.is_active() or not FileAccess.file_exists(request_path):
		return {"ok": false, "error": "Event Player Run input is unavailable."}
	if not proof_path.is_empty() and not FileAccess.file_exists(proof_path):
		return {"ok": false, "error": "Event Player semantic proof input is unavailable."}
	var process := preload("res://tools/content_suite/application_process.gd").for_scene("res://tools/content_suite/apps/event_player.tscn")
	if not process.get("ok", false):
		return process
	var arguments: PackedStringArray = process.arguments
	arguments.append_array([
		"--",
		"--content-set", _launch_context.get_content_set_root(),
		"--workspace", _launch_context.get_workspace_root(),
		"--run-request", ProjectSettings.globalize_path(request_path).simplify_path(),
	])
	return {"ok": true, "executable": process.executable, "arguments": arguments}


func _sync_run_event_player_button() -> void:
	var available: bool = (
		_launch_context.is_active() and _reader.is_open()
		and _document.get("ok", false) and not _selected_entry_name.is_empty()
		and _pending_count_total() == 0 and not _has_unstaged_message_draft()
	)
	var original_source := str(_document.get("source", {}).get("resolved_source", "")) == "original_arc"
	run_event_player_button.disabled = not available or not original_source
	if not available:
		run_event_player_button.tooltip_text = "Run requires a named workspace, a parsed entry, and no pending or unstaged edits."
	elif not original_source:
		run_event_player_button.tooltip_text = "Run opens original entries only."
	else:
		run_event_player_button.tooltip_text = "Publish a validated immutable Run request and open this entry in Event Player Analysis."


func _sync_translation_catalog_controls() -> void:
	var base_available: bool = (
		_launch_context.is_active() and _reader.is_open()
		and _document.get("ok", false) and not _selected_entry_name.is_empty()
		and str(_document.get("source", {}).get("resolved_source", "")) == "original_arc"
		and not _has_unstaged_message_draft()
	)
	var selected_pending := _pending_for_selected().size()
	var total_pending := _pending_count_total()
	catalog_export_button.disabled = not base_available or total_pending > 0
	catalog_import_button.disabled = not base_available or total_pending > 0
	catalog_update_button.disabled = (
		not base_available or selected_pending == 0 or total_pending != selected_pending
	)
	catalog_export_button.tooltip_text = (
		"Export source-bound identities for this original MES entry without original text or bytes."
		if not catalog_export_button.disabled
		else "Export requires an original parsed entry in a named workspace and no edits."
	)
	catalog_update_button.tooltip_text = (
		"Publish staged selected-entry translations as a new catalog revision."
		if not catalog_update_button.disabled
		else "Update requires staged edits only in this original MES entry."
	)
	catalog_import_button.tooltip_text = (
		"Reconcile an exact-source catalog and load all translated rows as pending edits."
		if not catalog_import_button.disabled
		else "Import requires an original parsed entry in a named workspace and no edits."
	)


func _exit_tree() -> void:
	_launch_context.close()
	_resolver.close()
	_reader.close()


func _on_archive_selected(path: String) -> void:
	_open_archive(path)


func _publish_run_request(
	path: String,
	start_kind := "code_offset",
	start_value := 0,
	semantic_diff := {},
	contextual_launch: Dictionary = {}
) -> Dictionary:
	if not _reader.is_open() or not _document.get("ok", false) or _selected_entry_name.is_empty():
		return _run_request_error("Select a parsed MES entry before creating a Run request.")
	if not _launch_context.is_active():
		return _run_request_error("MES Editor Run requires an active named workspace.")
	if _pending_count_total() > 0:
		return _run_request_error("Save or revert all pending MES edits before creating a Run request.")
	if _has_unstaged_message_draft():
		return _run_request_error("Stage or discard the current MES text draft before creating a Run request.")
	if not _overlay_root.is_empty() and not _manifest_fingerprint_is_stable(
		_overlay_root, _overlay_manifest_sha256
	):
		return _run_request_error("The active overlay changed; use Hot Reload before creating a Run request.")
	if str(start_kind) not in ["code_offset", "address_entry"] or not _json_integer(start_value) or int(start_value) < 0:
		return _run_request_error("MES Editor Run requires one nonnegative code offset or address-entry index.")
	if not _run_start_is_valid(str(start_kind), int(start_value)):
		return _run_request_error("MES Editor Run start is outside the selected entry or not a decodable instruction boundary.")
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var descriptor := _resolver.resolve(archive_name, _selected_entry_name)
	if not descriptor.get("ok", false):
		return _run_request_error(str(descriptor.get("error", "Effective MES could not be resolved.")))
	var effective_data := _resolver.read_resolved(descriptor)
	if effective_data.is_empty() and not _resolver.last_error.is_empty():
		return _run_request_error(_resolver.last_error)
	var source_entry_sha := _reader.get_entry_fingerprint(_selected_entry_name)
	var effective_entry_sha := OverlayPackageScript.sha256_bytes(effective_data)
	if (
		source_entry_sha.is_empty() or effective_entry_sha.is_empty()
		or effective_entry_sha != str(_document.get("entry_sha256", ""))
	):
		return _run_request_error("The selected MES changed after it was parsed; reopen it before Run.")
	var interface_contract := _run_interface_contract(
		str(descriptor.source), source_entry_sha, effective_entry_sha, semantic_diff
	)
	if not interface_contract.get("ok", false):
		return _run_request_error(str(interface_contract.get("error", "MES Run interface proof was rejected.")))
	interface_contract.erase("ok")
	var request := _run_request_builder.build(
		_launch_context.get_snapshot(),
		{
			"archive": archive_name.to_lower(), "entry": _selected_entry_name,
			"source": str(descriptor.source), "source_archive_sha256": _archive_sha256,
			"source_entry_sha256": source_entry_sha,
			"effective_entry_sha256": effective_entry_sha,
			"effective_byte_count": effective_data.size(),
		},
		{
			"mode": "analysis_entry", "start_kind": str(start_kind),
			"start_value": int(start_value), "catalog_id": "", "event_id": "",
			"preset_id": "", "preset_source": "none",
		} if contextual_launch.is_empty() else contextual_launch,
		interface_contract
	)
	if not request.get("ok", false):
		return _run_request_error(str(request.get("error", "MES Run request could not be built.")))
	var written := _publish_new_run_request(path, request, effective_entry_sha, effective_data.size())
	if not written.ok:
		return _run_request_error(str(written.error))
	status_label.text = "MES Editor Run request prepared for %s at %s %d; source ARC remains read-only." % [
		_selected_entry_name, str(start_kind), int(start_value),
	]
	return {
		"ok": true, "schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA,
		"path": str(written.path), "request": request,
	}


func _run_interface_contract(
	source: String,
	source_entry_sha: String,
	effective_entry_sha: String,
	semantic_diff: Dictionary
) -> Dictionary:
	if source == "original_arc":
		if effective_entry_sha != source_entry_sha:
			return {"ok": false, "error": "Original MES identity changed before Run."}
		return {
			"ok": true, "kind": "exact_original",
			"contract_schema": ContentCoreVersionScript.MES_EXACT_ORIGINAL_INTERFACE_SCHEMA,
			"proof_sha256": source_entry_sha, "source_entry_sha256": source_entry_sha,
			"output_entry_sha256": effective_entry_sha,
			"compatibility": "original_engine_compatible", "control_flow_compatible": true,
		}
	return {"ok": false, "error": "MES Editor Run opens original entries only."}


func _run_start_is_valid(kind: String, value: int) -> bool:
	if kind == "address_entry":
		return value >= 0 and value < (_document.get("entries", []) as Array).size()
	var bytecode: PackedByteArray = _document.get("bytecode", PackedByteArray())
	if value < 0 or value >= bytecode.size():
		return false
	return _decoder.decode_at(bytecode, value).get("ok", false)


func _publish_new_run_request(
	path: String, request: Dictionary, effective_sha256: String, effective_byte_count: int
) -> Dictionary:
	if path.get_extension().to_lower() != "json":
		return {"ok": false, "error": "MES Editor Run request output must use .json."}
	var output_path := ProjectSettings.globalize_path(path).simplify_path()
	if output_path.get_base_dir().to_lower() == _reader.archive_path.get_base_dir().to_lower():
		return {"ok": false, "error": "MES Editor Run request must be outside the source ARC directory."}
	if FileAccess.file_exists(output_path):
		return {"ok": false, "error": "MES Editor Run request output already exists."}
	var directory_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "error": "MES Editor Run request directory could not be created."}
	var temporary_path := output_path.get_base_dir().path_join(
		".%s.tmp-%d-%d" % [output_path.get_file(), OS.get_process_id(), Time.get_ticks_usec()]
	)
	if FileAccess.file_exists(temporary_path):
		return {"ok": false, "error": "MES Editor Run request temporary output already exists."}
	var output := FileAccess.open(temporary_path, FileAccess.WRITE)
	if output == null:
		return {"ok": false, "error": "MES Editor Run request temporary output could not be opened."}
	output.store_string(JSON.stringify(request, "", true, true) + "\n")
	output.close()
	var reopened = JSON.parse_string(FileAccess.get_file_as_string(temporary_path))
	var checked := (
		_run_request_builder.validate_for_workspace(reopened, _launch_context.get_snapshot())
		if reopened is Dictionary else {"ok": false}
	)
	var effective_checked := (
		_run_request_builder.validate_effective(reopened, effective_sha256, effective_byte_count)
		if reopened is Dictionary else {"ok": false}
	)
	if not checked.get("ok", false) or not effective_checked.get("ok", false):
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "MES Editor Run request failed its publication reopen."}
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "MES Editor Run request output appeared before publication."}
	var rename_error := DirAccess.rename_absolute(temporary_path, output_path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "MES Editor Run request could not be published."}
	return {"ok": true, "path": output_path}


func _run_request_error(error: String) -> Dictionary:
	status_label.text = error
	return {"ok": false, "schema": ContentCoreVersionScript.MES_EDITOR_RUN_REQUEST_SCHEMA, "error": error}


func _json_integer(value: Variant) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and float(value) == floor(float(value)) and abs(float(value)) <= 4294967295.0
	)


func _open_archive(path: String) -> void:
	if _reader.is_open() and not _pending_text_edits_by_entry.is_empty():
		status_label.text = "ARC switch blocked: save or revert all pending MES text edits first."
		return
	if _reader.is_open() and _has_unstaged_message_draft():
		status_label.text = "ARC switch blocked: stage or discard the current MES text draft first."
		return
	_mes_entries.clear()
	_archive_sha256 = ""
	_document.clear()
	_analysis.clear()
	_selected_entry_name = ""
	_text_messages.clear()
	_overlay_messages.clear()
	_pending_text_edits_by_entry.clear()
	_selected_message_offset = -1
	_text_cache.clear()
	_text_cache_root = ""
	_overlay_root = ""
	_overlay_manifest_sha256 = ""
	_resolver.close()
	_clear_analysis_views()
	if not _reader.open(path):
		archive_label.text = "No archive open"
		status_label.text = _reader.last_error
		return
	_archive_sha256 = _reader.get_archive_fingerprint()
	if _archive_sha256.is_empty():
		_reader.close()
		archive_label.text = "No archive open"
		status_label.text = "Could not fingerprint the opened MES ARC."
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	if not _resolver.register_original_archive(archive_name, _reader.archive_path):
		archive_label.text = "No archive open"
		status_label.text = _resolver.last_error
		_reader.close()
		_archive_sha256 = ""
		return
	_path_history.remember_source_path(_reader.archive_path)
	_path_history.apply_source_dialog(open_dialog)
	for entry in _reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension == "mes" or extension == "lib":
			_mes_entries.append(entry)
	archive_label.text = _reader.archive_path
	_rebuild_entry_tree()
	status_label.text = "%d MES/LIB entries; original ARC opened read-only" % _mes_entries.size()


func _on_text_cache_pressed() -> void:
	if not _reader.is_open():
		status_label.text = "Open mes.arc before selecting a text cache."
		return
	text_cache_dialog.popup_centered_ratio(0.75)


func _on_text_cache_selected(path: String) -> void:
	_configure_text_cache(path)


func _configure_text_cache(path: String) -> void:
	if not _reader.is_open():
		status_label.text = "Text cache requires an open mes.arc."
		return
	if not _text_cache.configure(path, _reader.get_archive_fingerprint()):
		_text_cache_root = ""
		_text_messages.clear()
		_rebuild_message_tree()
		status_label.text = "Text cache rejected: %s" % _text_cache.last_error
		return
	_text_cache_root = path
	_load_selected_text_projection()
	_rebuild_message_tree()
	status_label.text = "Hash-bound UTF-8 text cache loaded; original ARC remains authoritative."


func _on_filter_changed(_value: String) -> void:
	if _entry_selection_restore_active:
		return
	_rebuild_entry_tree()


func _rebuild_entry_tree() -> void:
	entry_tree.clear()
	var root := entry_tree.create_item()
	var filter := filter_edit.text.strip_edges().to_upper()
	for entry in _mes_entries:
		if not filter.is_empty() and not str(entry.name).to_upper().contains(filter):
			continue
		var item := entry_tree.create_item(root)
		item.set_text(0, entry.name)
		item.set_text(1, str(entry.size))
		item.set_metadata(0, entry.name)


func _on_entry_selected() -> void:
	if _entry_selection_restore_active:
		return
	var item := entry_tree.get_selected()
	if item == null:
		return
	var entry_name := str(item.get_metadata(0))
	if entry_name.to_upper() != _selected_entry_name.to_upper() and _has_unstaged_message_draft():
		status_label.text = "Entry switch blocked: stage or discard the current MES text draft first."
		_schedule_entry_tree_restore(_selected_entry_name)
		return
	if (
		entry_name.to_upper() != _selected_entry_name.to_upper()
		and not _overlay_root.is_empty()
		and not _manifest_fingerprint_is_stable(_overlay_root, _overlay_manifest_sha256)
	):
		status_label.text = "Entry switch blocked: the overlay manifest changed externally; use Hot Reload first."
		_schedule_entry_tree_restore(_selected_entry_name)
		return
	_load_entry(entry_name)


func _schedule_entry_tree_restore(entry_name: String) -> void:
	if _entry_selection_restore_pending:
		return
	_entry_selection_restore_pending = true
	call_deferred("_restore_entry_tree_selection", entry_name)


func _restore_entry_tree_selection(entry_name: String) -> void:
	_entry_selection_restore_pending = false
	_reselect_entry_tree_item(entry_name)


func _reselect_entry_tree_item(entry_name: String) -> void:
	var root := entry_tree.get_root()
	var item := root.get_first_child() if root != null else null
	while item != null:
		if str(item.get_metadata(0)).to_upper() == entry_name.to_upper():
			_entry_selection_restore_active = true
			item.select(0)
			_entry_selection_restore_active = false
			return
		item = item.get_next()
	# This function runs deferred after item_selected returns. A filter may have
	# hidden the entry whose draft must stay visible, so rebuild exactly once.
	_entry_selection_restore_active = true
	filter_edit.text = ""
	_rebuild_entry_tree()
	root = entry_tree.get_root()
	item = root.get_first_child() if root != null else null
	while item != null:
		if str(item.get_metadata(0)).to_upper() == entry_name.to_upper():
			item.select(0)
			break
		item = item.get_next()
	_entry_selection_restore_active = false


func _load_entry(entry_name: String) -> Dictionary:
	_selected_entry_name = entry_name
	_selected_message_offset = -1
	_document.clear()
	_analysis.clear()
	_text_messages.clear()
	_overlay_messages.clear()
	_clear_analysis_views()
	var entry := _reader.get_entry(_selected_entry_name)
	if entry.is_empty():
		return _entry_load_error("MES entry is missing from the original ARC: %s" % _selected_entry_name)
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var descriptor := _resolver.resolve(archive_name, _selected_entry_name)
	if not descriptor.ok:
		return _entry_load_error(str(descriptor.error))
	var data := _resolver.read_resolved(descriptor)
	if data.is_empty() and not _resolver.last_error.is_empty():
		return _entry_load_error(_resolver.last_error)
	_document = _parser.parse(data, {
		"archive": archive_name,
		"entry": _selected_entry_name,
		"archive_offset": entry.offset,
		"size": entry.size,
		"resolved_source": descriptor.source,
	})
	if not _document.ok:
		return _entry_load_error(str(_document.error))
	_analysis = _analysis_builder.build(_document)
	_load_selected_text_projection()
	var overlay_load := _load_selected_overlay_projection()
	_build_address_tree()
	_rebuild_message_tree()
	_rebuild_reference_trees()
	_refresh_details()
	if not overlay_load.ok:
		return _entry_load_error("Overlay rejected for %s: %s" % [_selected_entry_name, overlay_load.error])
	if not _analysis.ok:
		status_label.text = "Container parsed, but strict analysis stopped: %s" % _analysis.error
		return {"ok": true, "analysis_ok": false, "source": str(descriptor.source)}
	status_label.text = "%s from %s: %d strict-prefix instructions, %d indexed messages, %d stopped boundaries" % [
		_selected_entry_name,
		descriptor.source,
		int(_analysis.instruction_count),
		int(_analysis.message_count),
		int(_analysis.diagnostic_count),
	]
	var root := address_tree.get_root()
	if root != null and root.get_first_child() != null:
		root.get_first_child().select(0)
		_show_selected_address(root.get_first_child())
	return {"ok": true, "analysis_ok": true, "source": str(descriptor.source)}


func _entry_load_error(error: String) -> Dictionary:
	status_label.text = error
	return {"ok": false, "error": error}


func _build_address_tree() -> void:
	address_tree.clear()
	var root := address_tree.create_item()
	var bootstrap: Dictionary = _document.bootstrap
	if int(bootstrap.size) > 0:
		var bootstrap_item := address_tree.create_item(root)
		bootstrap_item.set_text(0, "bootstrap")
		bootstrap_item.set_text(1, "0x00000000")
		bootstrap_item.set_text(2, str(bootstrap.size))
		bootstrap_item.set_metadata(0, {"offset": 0, "end_offset": bootstrap.end_offset})
	for address in _document.entries:
		var address_item := address_tree.create_item(root)
		address_item.set_text(0, "#%04d" % int(address.index))
		address_item.set_text(1, "0x%08X" % int(address.offset))
		address_item.set_text(2, str(address.size))
		address_item.set_metadata(0, {"offset": address.offset, "end_offset": address.end_offset})


func _refresh_details() -> void:
	if _document.is_empty() or not _document.get("ok", false):
		details.text = "Select an entry to inspect its lossless MES container and strict structural projections."
		return
	var header: Dictionary = _document.header
	var bootstrap: Dictionary = _document.bootstrap
	var lines: Array[String] = [
		"[b]%s[/b]" % _selected_entry_name,
		"Entry SHA-256: %s" % _document.entry_sha256,
		"Address table: %d entries / %d bytes; code: 0x%X / %d bytes" % [header.entry_count, header.table_size, header.code_offset, header.code_size],
		"Bootstrap: %d bytes; offsets: %s" % [bootstrap.size, header.offset_basis],
	]
	if _analysis.get("ok", false):
		lines.append("Strict-prefix index: %d instructions / %d messages / %d code refs / %d state refs" % [
			_analysis.instruction_count,
			_analysis.message_count,
			_analysis.code_reference_count,
			_analysis.state_reference_count,
		])
		lines.append("Exact resource refs: %d (strict or bounded-scan; see Resources)" % int(_analysis.resource_reference_count))
		lines.append("Stopped boundaries: %d (no bytes guessed past them)" % int(_analysis.diagnostic_count))
	lines.append("UTF-8 text: cache %d / overlay %d / pending %d" % [
		_text_messages.size(),
		_overlay_messages.size(),
		_pending_for_selected().size(),
	])
	lines.append("Resolved MES source: %s" % str(_document.get("source", {}).get("resolved_source", "original_arc")))
	details.text = "\n".join(lines)


func _load_selected_text_projection() -> void:
	_text_messages.clear()
	if _text_cache_root.is_empty() or _selected_entry_name.is_empty() or not _document.get("ok", false):
		return
	var cached := _text_cache.load_entry(_selected_entry_name, _reader.get_entry_fingerprint(_selected_entry_name))
	if cached.ok:
		_text_messages = cached.messages


func _on_overlay_load_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	overlay_load_dialog.popup_centered_ratio(0.75)


func _on_overlay_load_selected(path: String) -> void:
	if not _can_change_loaded_overlay():
		return
	var configured := _configure_loaded_overlay(path)
	if not configured.ok:
		status_label.text = "Overlay rejected: %s" % configured.error
		return
	var activated := _activate_loaded_overlay(configured)
	if not activated.ok:
		status_label.text = "Overlay rejected: %s" % activated.error
		return
	status_label.text = "Overlay loaded: %d MES replacement(s), %d UTF-8 projection(s); selected entry reopened." % [
		int(configured.replacement_count),
		int(configured.projection_count),
	]
	if _definitions_panel != null:
		_definitions_panel.refresh()


func _on_hot_reload_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	if _overlay_root.is_empty():
		status_label.text = "Load an overlay package before using Hot Reload."
		return
	var configured := _configure_loaded_overlay(_overlay_root)
	if not configured.ok:
		status_label.text = "Overlay Hot Reload failed: %s" % configured.error
		return
	var activated := _activate_loaded_overlay(configured)
	if not activated.ok:
		status_label.text = "Overlay Hot Reload failed: %s" % activated.error
		return
	status_label.text = "Hot Reloaded overlay: %d MES replacement(s), %d UTF-8 projection(s); selected entry reopened." % [
		int(configured.replacement_count),
		int(configured.projection_count),
	]
	if _definitions_panel != null:
		_definitions_panel.refresh()


func _on_clear_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	if _overlay_root.is_empty():
		status_label.text = "No overlay read layer is loaded."
		return
	_resolver.clear_overlay()
	_overlay_root = ""
	_overlay_manifest_sha256 = ""
	_overlay_messages.clear()
	var refreshed := _refresh_after_overlay_change()
	if not refreshed.ok:
		status_label.text = "Overlay cleared, but the original MES could not be reopened: %s" % refreshed.error
		return
	status_label.text = "Cleared the overlay read layer; selected MES now resolves from the original ARC and hash-bound cache."


func _can_change_loaded_overlay() -> bool:
	if not _reader.is_open():
		status_label.text = "Open mes.arc before changing the overlay read layer."
		return false
	if not _pending_text_edits_by_entry.is_empty():
		status_label.text = "Save or revert all pending MES text edits before changing the overlay read layer."
		return false
	if _has_unstaged_message_draft():
		status_label.text = "Stage or discard the current MES text draft before changing the overlay read layer."
		return false
	return true


func _configure_loaded_overlay(path: String) -> Dictionary:
	var package_root := ProjectSettings.globalize_path(path).simplify_path()
	var manifest_path := package_root.path_join("manifest.json")
	var manifest_sha := FileAccess.get_sha256(manifest_path)
	if manifest_sha.is_empty():
		return {"ok": false, "error": "Overlay manifest could not be fingerprinted."}
	var loaded := _overlay_package.load_manifest(package_root)
	if not loaded.ok:
		return loaded
	if not _manifest_fingerprint_is_stable(package_root, manifest_sha):
		return {"ok": false, "error": "Overlay manifest changed during validation; retry Hot Reload."}
	var candidate := ContentResolverScript.new()
	var archive_leaf := _reader.archive_path.replace("\\", "/").get_file()
	if not candidate.register_original_archive(archive_leaf, _reader.archive_path):
		var register_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": register_error}
	if not candidate.configure_overlay(package_root):
		var configure_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": configure_error}
	if not _manifest_fingerprint_is_stable(package_root, manifest_sha):
		candidate.close()
		return {"ok": false, "error": "Overlay manifest changed while configuring the candidate resolver; retry Hot Reload."}
	var archive_name := archive_leaf.to_upper()
	var replacement_count := 0
	for untyped_record in loaded.manifest.get("replacements", []):
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == archive_name and str(record.target_entry).get_extension().to_lower() in ["mes", "lib"]:
			var entry := _reader.get_entry(str(record.target_entry))
			if entry.is_empty():
				candidate.close()
				return {"ok": false, "error": "Overlay MES target is missing from the original ARC: %s" % str(record.target_entry)}
			var descriptor := candidate.resolve(archive_leaf, str(entry.name))
			if not descriptor.ok:
				candidate.close()
				return {"ok": false, "error": str(descriptor.error)}
			if (
				str(descriptor.source) != "overlay"
				or str(descriptor.sha256) != str(record.replacement_sha256)
				or str(descriptor.path).simplify_path() != package_root.path_join(str(record.replacement_path)).simplify_path()
			):
				candidate.close()
				return {"ok": false, "error": "Candidate resolver does not match the validated MES replacement: %s" % str(entry.name)}
			var replacement_data := candidate.read_resolved(descriptor)
			if replacement_data.is_empty() and not candidate.last_error.is_empty():
				var read_error := candidate.last_error
				candidate.close()
				return {"ok": false, "error": read_error}
			var parsed := _parser.parse(replacement_data, {
				"archive": archive_leaf,
				"entry": str(entry.name),
				"archive_offset": entry.offset,
				"size": entry.size,
				"resolved_source": "overlay",
			})
			if not parsed.ok:
				candidate.close()
				return {"ok": false, "error": "Overlay MES replacement could not be parsed: %s" % str(parsed.error)}
			replacement_count += 1
	var projection_count := 0
	for untyped_record in loaded.manifest.get("projections", []):
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == archive_name and str(record.get("kind", "")) == "mes_text":
			var entry := _reader.get_entry(str(record.target_entry))
			if entry.is_empty():
				candidate.close()
				return {"ok": false, "error": "Overlay MES projection target is missing from the original ARC: %s" % str(record.target_entry)}
			var projection := _overlay_package.load_mes_text_projection(
				package_root,
				archive_leaf,
				str(entry.name),
				_reader.get_archive_fingerprint(),
				_reader.get_entry_fingerprint(str(entry.name))
			)
			if not projection.ok:
				candidate.close()
				return {"ok": false, "error": str(projection.error)}
			if not bool(projection.get("found", false)) or not _projection_record_matches(record, projection.get("record", {})):
				candidate.close()
				return {"ok": false, "error": "Candidate MES projection changed during validation: %s" % str(entry.name)}
			projection_count += 1
	if not _candidate_mes_resolution_matches_manifest(candidate, loaded.manifest, package_root, archive_leaf):
		var resolution_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": resolution_error}
	if not _selected_entry_name.is_empty():
		var descriptor := candidate.resolve(archive_leaf, _selected_entry_name)
		if not descriptor.ok:
			candidate.close()
			return {"ok": false, "error": str(descriptor.error)}
		var selected_data := candidate.read_resolved(descriptor)
		if selected_data.is_empty() and not candidate.last_error.is_empty():
			var read_error := candidate.last_error
			candidate.close()
			return {"ok": false, "error": read_error}
	if not _manifest_fingerprint_is_stable(package_root, manifest_sha):
		candidate.close()
		return {"ok": false, "error": "Overlay manifest changed before candidate activation; retry Hot Reload."}
	return {
		"ok": true,
		"resolver": candidate,
		"root": package_root,
		"manifest_sha256": manifest_sha,
		"replacement_count": replacement_count,
		"projection_count": projection_count,
	}


func _manifest_fingerprint_is_stable(package_root: String, expected_sha256: String) -> bool:
	return (
		expected_sha256.length() == 64
		and FileAccess.get_sha256(package_root.path_join("manifest.json")) == expected_sha256
	)


func _projection_record_matches(expected: Dictionary, actual: Dictionary) -> bool:
	if actual.is_empty():
		return false
	for field in [
		"base_archive_sha256", "original_entry_sha256", "projection_sha256",
		"target_archive", "target_entry", "projection_path", "kind", "schema",
	]:
		if str(actual.get(field, "")) != str(expected.get(field, "")):
			return false
	return true


func _candidate_mes_resolution_matches_manifest(
	candidate,
	manifest: Dictionary,
	package_root: String,
	archive_name: String
) -> bool:
	for entry in _mes_entries:
		var entry_name := str(entry.name)
		var descriptor: Dictionary = candidate.resolve(archive_name, entry_name)
		if not descriptor.ok:
			candidate.last_error = str(descriptor.error)
			return false
		var expected := _overlay_package.find_replacement(manifest, archive_name, entry_name)
		if expected.is_empty():
			if str(descriptor.source) != "original_arc":
				candidate.last_error = "Candidate resolver contains an unvalidated MES replacement: %s" % entry_name
				return false
			continue
		if (
			str(descriptor.source) != "overlay"
			or str(descriptor.sha256) != str(expected.replacement_sha256)
			or str(descriptor.path).simplify_path() != package_root.path_join(str(expected.replacement_path)).simplify_path()
		):
			candidate.last_error = "Candidate resolver differs from the validated MES manifest: %s" % entry_name
			return false
	return true


func _activate_loaded_overlay(configured: Dictionary) -> Dictionary:
	var candidate = configured.resolver
	if not _manifest_fingerprint_is_stable(str(configured.root), str(configured.manifest_sha256)):
		candidate.close()
		return {"ok": false, "error": "Overlay manifest changed before activation; retry Hot Reload."}
	var previous_view := _snapshot_loaded_entry_state()
	var previous_resolver = _resolver
	var previous_root := _overlay_root
	var previous_manifest_sha := _overlay_manifest_sha256
	_resolver = candidate
	_overlay_root = str(configured.root)
	_overlay_manifest_sha256 = str(configured.manifest_sha256)
	var refreshed := _refresh_after_overlay_change()
	if refreshed.ok and _manifest_fingerprint_is_stable(str(configured.root), str(configured.manifest_sha256)):
		if _launch_context.is_active() and str(configured.root).simplify_path().to_lower() == _launch_context.get_workspace_root().simplify_path().to_lower():
			var workspace_refresh := _launch_context.refresh()
			if not workspace_refresh.get("ok", false):
				refreshed = {"ok": false, "error": "The named workspace could not be refreshed: %s" % str(workspace_refresh.error)}
	if refreshed.ok and _manifest_fingerprint_is_stable(str(configured.root), str(configured.manifest_sha256)):
		previous_resolver.close()
		return {"ok": true}
	var activation_error := (
		str(refreshed.error)
		if not refreshed.ok
		else "Overlay manifest changed while reopening the selected entry; retry Hot Reload."
	)
	_resolver.close()
	_resolver = previous_resolver
	_overlay_root = previous_root
	_overlay_manifest_sha256 = previous_manifest_sha
	_restore_loaded_entry_state(previous_view)
	return {"ok": false, "error": activation_error}


func _snapshot_loaded_entry_state() -> Dictionary:
	return {
		"selected_entry_name": _selected_entry_name,
		"selected_message_offset": _selected_message_offset,
		"document": _document.duplicate(true),
		"analysis": _analysis.duplicate(true),
		"text_messages": _text_messages.duplicate(true),
		"overlay_messages": _overlay_messages.duplicate(true),
	}


func _restore_loaded_entry_state(snapshot: Dictionary) -> void:
	_selected_entry_name = str(snapshot.get("selected_entry_name", ""))
	_document = snapshot.get("document", {}).duplicate(true)
	_analysis = snapshot.get("analysis", {}).duplicate(true)
	_text_messages = snapshot.get("text_messages", {}).duplicate(true)
	_overlay_messages = snapshot.get("overlay_messages", {}).duplicate(true)
	var message_offset := int(snapshot.get("selected_message_offset", -1))
	_clear_analysis_views()
	if not _document.get("ok", false):
		return
	_build_address_tree()
	_rebuild_message_tree()
	_rebuild_reference_trees()
	_refresh_details()
	var root := address_tree.get_root()
	if root != null and root.get_first_child() != null:
		root.get_first_child().select(0)
		_show_selected_address(root.get_first_child())
	if message_offset < 0:
		return
	var message_root := message_tree.get_root()
	var item := message_root.get_first_child() if message_root != null else null
	while item != null:
		if int(item.get_metadata(0)) == message_offset:
			item.select(0)
			_selected_message_offset = message_offset
			_populate_message_edit()
			return
		item = item.get_next()


func _refresh_after_overlay_change() -> Dictionary:
	var selected_entry := _selected_entry_name
	if not selected_entry.is_empty() and not _reader.get_entry(selected_entry).is_empty():
		return _load_entry(selected_entry)
	else:
		_overlay_messages.clear()
		_update_message_edit_controls()
	return {"ok": true}


func _load_selected_overlay_projection() -> Dictionary:
	_overlay_messages.clear()
	if _overlay_root.is_empty() or _selected_entry_name.is_empty() or not _document.get("ok", false):
		return {"ok": true, "found": false}
	if not _manifest_fingerprint_is_stable(_overlay_root, _overlay_manifest_sha256):
		return {"ok": false, "error": "Overlay manifest changed externally; use Hot Reload before reopening MES entries."}
	var loaded := _overlay_package.load_mes_text_projection(
		_overlay_root,
		_reader.archive_path.replace("\\", "/").get_file(),
		_selected_entry_name,
		_reader.get_archive_fingerprint(),
		_reader.get_entry_fingerprint(_selected_entry_name)
	)
	if loaded.ok and loaded.found:
		_overlay_messages = loaded.messages
	if str(_document.entry_sha256) != _reader.get_entry_fingerprint(_selected_entry_name):
		var retained := AuthoringSessionScript.BindingScript.find_proof(_overlay_root, _reader.get_entry_fingerprint(_selected_entry_name), str(_document.entry_sha256))
		if retained.get("ok", false):
			_authoring_proof_path = str(retained.path)
			var original := _reader.read_entry(_selected_entry_name)
			if str(retained.proof.schema) == "kakyu_mes_semantic_diff/v4":
				var binding := AuthoringSessionScript.BindingScript.bind(original, _resolver.read_resolved(_resolver.resolve("mes.arc", _selected_entry_name)), retained.proof)
				var mapped := AuthoringSessionScript.BindingScript.map_text(_overlay_messages, binding) if binding.get("ok", false) else binding
				if not mapped.get("ok", false):
					_overlay_messages.clear()
					return mapped
				_overlay_messages = mapped.messages
			elif str(retained.proof.get("schema", "")) == AuthoringSessionScript.SemanticDiffChainScript.SCHEMA:
				var bundle := AuthoringSessionScript.read_bundle(str(retained.directory))
				var validated := AuthoringSessionScript.validate_source(bundle, original) if bundle.get("ok", false) else bundle
				if not validated.get("ok", false):
					_overlay_messages.clear()
					return validated
				if validated.has("points"):
					var mapped := AuthoringSessionScript.BindingScript.map_text(_overlay_messages, validated)
					if not mapped.get("ok", false):
						_overlay_messages.clear()
						return mapped
					_overlay_messages = mapped.messages
	return loaded


func _on_message_search_changed(_value: String) -> void:
	_rebuild_message_tree()


func _rebuild_message_tree() -> void:
	message_tree.clear()
	var root := message_tree.create_item()
	if not _analysis.get("ok", false):
		return
	var query := message_search_edit.text.strip_edges()
	var hex_query := ""
	if query.to_lower().begins_with("hex:"):
		hex_query = query.substr(4).replace(" ", "").to_lower()
	var match_count := 0
	for untyped_message in _message_records():
		var message: Dictionary = untyped_message
		var decoded := _decode_message_cp932(message)
		var projection := _projection_for_message(message)
		var display_text := str(projection.text) if not projection.is_empty() else (
			str(decoded.text) if decoded.ok else "Native presentation bytes (not CP932 dialogue)"
		)
		if not query.is_empty():
			var matches := false
			if not hex_query.is_empty():
				matches = str(message.raw_hex).contains(hex_query)
			else:
				matches = display_text.to_lower().contains(query.to_lower())
				if not matches:
					var raw_bytes: PackedByteArray = message.raw_bytes
					matches = raw_bytes.get_string_from_ascii().to_lower().contains(query.to_lower())
			if not matches:
				continue
		var item := message_tree.create_item(root)
		item.set_text(0, "0x%08X" % int(message.source_offset))
		var native_projection_match := _message_native_projection_matches(message)
		item.set_text(1, "%s%s%s" % [
			str(message.region),
			" [native bytes]" if not bool(decoded.ok) else "",
			" [native boundary mismatch]" if not bool(message.get("projection_only", false)) and not native_projection_match else "",
		])
		item.set_text(2, display_text)
		var tooltip := display_text if not projection.is_empty() else "%s\nCP932 bytes: %s" % [display_text, str(message.raw_hex)]
		if not bool(decoded.ok):
			tooltip = (
				"Native presentation bytes are retained for lossless analysis and are not editable dialogue.\n"
				+ "Raw bytes (hex): %s\nCP932 diagnostic: %s"
			) % [str(message.raw_hex), str(decoded.get("error", "invalid sequence"))]
		if not bool(message.get("projection_only", false)) and not native_projection_match:
			tooltip += "\nNative double-byte handler stops before this projection ends; binary outputs are disabled."
		item.set_tooltip_text(2, tooltip)
		item.set_metadata(0, int(message.source_offset))
		match_count += 1
	_update_message_edit_controls()
	if not query.is_empty():
		status_label.text = "%d message match(es) in %s" % [match_count, _selected_entry_name]


func _projection_for_message(message: Dictionary) -> Dictionary:
	# Authored text must never turn an invalid native byte pair into apparent dialogue.
	# The analysis row remains visible and searchable by hex as lossless evidence.
	if not bool(_decode_message_cp932(message).ok):
		return {}
	var offset := int(message.source_offset)
	var pending: Dictionary = _pending_for_selected().get(offset, {})
	if not pending.is_empty() and str(pending.get("raw_sha256", "")) == str(message.raw_sha256):
		return pending
	var overlay: Dictionary = _overlay_messages.get(offset, {})
	if not overlay.is_empty() and str(overlay.get("raw_sha256", "")) == str(message.raw_sha256):
		return overlay
	var cached: Dictionary = _text_messages.get(offset, {})
	if not cached.is_empty() and str(cached.get("raw_sha256", "")) == str(message.raw_sha256):
		return cached
	return {}


func _on_message_text_submitted(_value: String) -> void:
	_on_stage_text_pressed()


func _on_message_text_changed(_value: String) -> void:
	_update_message_edit_controls()


func _on_stage_text_pressed() -> void:
	var message := _message_record_at(_selected_message_offset)
	if message.is_empty() or message.get("projection_only", false):
		status_label.text = "Select a strictly indexed source message before staging an edit."
		return
	if not _message_is_authorable(message):
		status_label.text = "Native presentation bytes are diagnostic-only and cannot be staged as dialogue."
		return
	var pending := _pending_for_selected()
	pending[_selected_message_offset] = {
		"source_offset": _selected_message_offset,
		"raw_sha256": str(message.raw_sha256),
		"text": message_edit.text,
		"source_archive_sha256": _archive_sha256,
		"source_entry_sha256": str(_document.get("entry_sha256", "")),
		"native_stream_projection_match": _message_native_projection_matches(message),
	}
	_pending_text_edits_by_entry[_selected_entry_name.to_upper()] = pending
	_rebuild_message_tree()
	_refresh_details()
	status_label.text = (
		"Staged UTF-8 edit at 0x%08X; native boundary mismatch keeps binary outputs disabled."
		if not _message_native_projection_matches(message)
		else "Staged UTF-8 edit at 0x%08X; original MES remains unchanged."
	) % _selected_message_offset


func _on_revert_text_pressed() -> void:
	var key := _selected_entry_name.to_upper()
	var pending: Dictionary = _pending_text_edits_by_entry.get(key, {})
	if _selected_message_offset < 0 or not pending.has(_selected_message_offset):
		status_label.text = "The selected message has no pending edit to revert."
		return
	pending.erase(_selected_message_offset)
	if pending.is_empty():
		_pending_text_edits_by_entry.erase(key)
	else:
		_pending_text_edits_by_entry[key] = pending
	_rebuild_message_tree()
	_populate_message_edit()
	_refresh_details()
	status_label.text = "Pending edit reverted; loaded overlay/cache text is shown again."


func _on_overlay_save_pressed() -> void:
	if _reject_unstaged_draft("saving the MES overlay"):
		return
	if not _reader.is_open() or _pending_count_total() == 0:
		status_label.text = "Stage at least one UTF-8 edit before saving."
		return
	var policy := _assess_pending_output_policy("remake_utf8_overlay")
	if not policy.get("ok", false) or not policy.get("ready", false):
		status_label.text = _output_policy_refusal("UTF-8 overlay save", policy)
		return
	overlay_save_dialog.popup_centered_ratio(0.75)


func _on_overlay_detach_pressed() -> void:
	if _reject_unstaged_draft("detaching the saved projection"):
		return
	if _overlay_root.is_empty() or _selected_entry_name.is_empty() or _overlay_messages.is_empty():
		status_label.text = "The selected entry has no loaded MES text projection to detach."
		return
	if not _pending_for_selected().is_empty():
		status_label.text = "Save or revert pending edits in this entry before detaching its saved projection."
		return
	var detached := _overlay_package.remove_mes_text_projection(
		_overlay_root,
		_reader.archive_path.replace("\\", "/").get_file(),
		_selected_entry_name
	)
	if not detached.ok:
		status_label.text = "MES text projection detach failed: %s" % detached.error
		return
	_overlay_manifest_sha256 = FileAccess.get_sha256(_overlay_root.path_join("manifest.json"))
	_overlay_messages.clear()
	_rebuild_message_tree()
	_populate_message_edit()
	_refresh_details()
	status_label.text = "Detached saved projection for %s; payload retained for recovery." % _selected_entry_name


func _on_overlay_save_selected(path: String) -> void:
	if _reject_unstaged_draft("saving the MES overlay"):
		return
	if not _reader.is_open() or _pending_count_total() == 0:
		status_label.text = "Overlay save stopped because the session has no pending edits."
		return
	var policy := _assess_pending_output_policy("remake_utf8_overlay")
	if not policy.get("ok", false) or not policy.get("ready", false):
		status_label.text = _output_policy_refusal("UTF-8 overlay save", policy)
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var archive_sha := _reader.get_archive_fingerprint()
	var manifest_path := ProjectSettings.globalize_path(path).simplify_path().path_join("manifest.json")
	var edits_by_entry: Dictionary = {}
	var edit_count := 0
	for untyped_entry_key in _pending_text_edits_by_entry:
		var entry_key := str(untyped_entry_key)
		var entry := _reader.get_entry(entry_key)
		if entry.is_empty():
			status_label.text = "Overlay save stopped because a pending entry is missing: %s" % entry_key
			return
		var entry_name := str(entry.name)
		var merged: Dictionary = {}
		if FileAccess.file_exists(manifest_path):
			var loaded := _overlay_package.load_mes_text_projection(
				path,
				archive_name,
				entry_name,
				archive_sha,
				_reader.get_entry_fingerprint(entry_name)
			)
			if not loaded.ok:
				status_label.text = "Overlay save stopped while loading %s: %s" % [entry_name, loaded.error]
				return
			if loaded.found:
				merged = loaded.messages.duplicate(true)
		var pending: Dictionary = _pending_text_edits_by_entry[untyped_entry_key]
		for untyped_offset in pending:
			merged[int(untyped_offset)] = pending[untyped_offset]
		var edits: Array[Dictionary] = []
		for untyped_offset in merged:
			var edit: Dictionary = merged[untyped_offset]
			edits.append({
				"source_offset": int(untyped_offset),
				"raw_sha256": str(edit.raw_sha256),
				"text": str(edit.text),
			})
		edit_count += edits.size()
		edits_by_entry[entry_name] = edits
	var staged := _overlay_package.stage_mes_text_projections(
		path,
		_reader,
		archive_name,
		edits_by_entry
	)
	if not staged.ok:
		status_label.text = "Overlay save failed: %s" % staged.error
		return
	var configured := _configure_loaded_overlay(path)
	if not configured.ok:
		status_label.text = "Overlay was written, but reopen preflight failed; pending edits were retained: %s" % configured.error
		return
	var activated := _activate_loaded_overlay(configured)
	if not activated.ok:
		status_label.text = "Overlay was written, but activation failed; pending edits were retained: %s" % activated.error
		return
	_pending_text_edits_by_entry.clear()
	_rebuild_message_tree()
	_populate_message_edit()
	_refresh_details()
	status_label.text = "Saved %d UTF-8 edit(s) across %d entry/entries; original ARC remains read-only." % [edit_count, edits_by_entry.size()]


func _on_binary_overlay_save_pressed() -> void:
	if _reject_unstaged_draft("saving the CP932 binary overlay"):
		return
	if not _reader.is_open() or _pending_count_total() == 0:
		status_label.text = "Stage at least one text edit before saving a CP932 binary overlay."
		return
	if not _pending_native_projections_match():
		status_label.text = "CP932 binary output requires every edit to match the EXE-confirmed native text boundary."
		return
	var policy := _assess_pending_output_policy("original_cp932_candidate")
	if not policy.get("ok", false) or not policy.get("ready", false):
		status_label.text = _output_policy_refusal("CP932 binary overlay", policy)
		return
	binary_overlay_save_dialog.popup_centered_ratio(0.75)


func _on_binary_overlay_save_selected(path: String) -> void:
	if _reject_unstaged_draft("saving the CP932 binary overlay"):
		return
	if not _reader.is_open() or _pending_count_total() == 0:
		status_label.text = "CP932 binary save stopped because the session has no pending edits."
		return
	if not _pending_native_projections_match():
		status_label.text = "CP932 binary save stopped: one or more messages cross an EXE-confirmed native text boundary."
		return
	var policy := _assess_pending_output_policy("original_cp932_candidate")
	if not policy.get("ok", false) or not policy.get("ready", false):
		status_label.text = _output_policy_refusal("CP932 binary overlay", policy)
		return
	var prepared := _prepare_binary_patch_batch(true)
	if not prepared.ok:
		status_label.text = "CP932 binary save stopped: %s" % prepared.error
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var replacement_data_by_entry: Dictionary = prepared.replacements
	var edit_count := int(prepared.edit_count)
	var staged := _overlay_package.stage_replacements(
		path,
		_reader,
		archive_name,
		replacement_data_by_entry,
		"original_engine_unverified",
		"cp932"
	)
	if not staged.ok:
		status_label.text = "CP932 binary overlay save failed: %s" % staged.error
		return
	var configured := _configure_loaded_overlay(path)
	if not configured.ok:
		status_label.text = "CP932 binary overlay was written, but reopen preflight failed; pending edits were retained: %s" % configured.error
		return
	var activated := _activate_loaded_overlay(configured)
	if not activated.ok:
		status_label.text = "CP932 binary overlay was written, but activation failed; pending edits were retained: %s" % activated.error
		return
	_pending_text_edits_by_entry.clear()
	_rebuild_message_tree()
	_populate_message_edit()
	_refresh_details()
	status_label.text = (
		"Saved %d equal-length CP932 edit(s) across %d entry/entries as an original-engine-unverified binary candidate; "
		+ "original-engine playback is unverified and the original ARC remains read-only."
	) % [edit_count, replacement_data_by_entry.size()]


func _on_binary_arc_export_pressed() -> void:
	if _reject_unstaged_draft("exporting the CP932 ARC copy"):
		return
	if not _reader.is_open() or _pending_count_total() == 0:
		status_label.text = "Stage at least one text edit before exporting a CP932 ARC copy."
		return
	if not _pending_native_projections_match():
		status_label.text = "CP932 ARC export requires every edit to match the EXE-confirmed native text boundary."
		return
	var policy := _assess_pending_output_policy("original_cp932_candidate")
	if not policy.get("ok", false) or not policy.get("ready", false):
		status_label.text = _output_policy_refusal("CP932 ARC export", policy)
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	binary_arc_export_dialog.current_file = "%s-cp932.arc" % archive_name.get_basename()
	binary_arc_export_dialog.popup_centered_ratio(0.75)


func _on_binary_arc_export_path_selected(path: String) -> void:
	if _reject_unstaged_draft("exporting the CP932 ARC copy"):
		return
	if not _reader.is_open() or _pending_count_total() == 0:
		status_label.text = "CP932 ARC export stopped because the session has no pending edits."
		return
	if not _pending_native_projections_match():
		status_label.text = "CP932 ARC export stopped: one or more messages cross an EXE-confirmed native text boundary."
		return
	var policy := _assess_pending_output_policy("original_cp932_candidate")
	if not policy.get("ok", false) or not policy.get("ready", false):
		status_label.text = _output_policy_refusal("CP932 ARC export", policy)
		return
	if path.get_extension().to_lower() != "arc":
		status_label.text = "New MES archive output must use the .arc extension."
		return
	var prepared := _prepare_binary_patch_batch(true)
	if not prepared.ok:
		status_label.text = "CP932 ARC export stopped: %s" % prepared.error
		return
	var result := ArcProvenanceScript.new().materialize_copy_if_source_matches(
		_reader.archive_path,
		path,
		_archive_sha256,
		prepared.replacements,
		"original_engine_unverified"
	)
	if not result.ok:
		status_label.text = "CP932 ARC export failed: %s" % result.error
		return
	status_label.text = (
		"Verified new ARC copy and provenance saved with %d equal-length CP932 edit(s): %s; "
		+ "original-engine playback remains unverified and the source is unchanged."
	) % [int(prepared.edit_count), result.path]


func _prepare_binary_patch_batch(require_native_projection_match := false) -> Dictionary:
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var replacement_data_by_entry := {}
	var edit_count := 0
	for untyped_entry_key in _pending_text_edits_by_entry:
		var entry_name := str(untyped_entry_key)
		var descriptor := _resolver.resolve(archive_name, entry_name)
		if not descriptor.ok:
			return {"ok": false, "error": "%s resolve failed: %s" % [entry_name, descriptor.error]}
		var source_data := _resolver.read_resolved(descriptor)
		if source_data.is_empty() and not _resolver.last_error.is_empty():
			return {"ok": false, "error": "%s read failed: %s" % [entry_name, _resolver.last_error]}
		var edits: Array[Dictionary] = []
		var pending: Dictionary = _pending_text_edits_by_entry[untyped_entry_key]
		for untyped_offset in pending:
			var edit: Dictionary = pending[untyped_offset]
			edits.append({
				"source_offset": int(untyped_offset),
				"raw_sha256": str(edit.raw_sha256),
				"text": str(edit.text),
			})
		var patched := _mes_text_patcher.patch_equal_length(
			source_data,
			edits,
			require_native_projection_match
		)
		if not patched.ok:
			return {"ok": false, "error": "%s: %s" % [entry_name, patched.error]}
		replacement_data_by_entry[entry_name] = patched.data
		edit_count += edits.size()
	return {"ok": true, "replacements": replacement_data_by_entry, "edit_count": edit_count}


func _assess_pending_output_policy(target_name: String) -> Dictionary:
	if target_name not in ["remake_utf8_overlay", "original_cp932_candidate"]:
		return {"ok": false, "error": "Unknown MES text output-policy target."}
	if not _reader.is_open() or _pending_count_total() == 0:
		return {"ok": false, "error": "No pending MES text edits are available for policy assessment."}
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var live_archive_sha := FileAccess.get_sha256(_reader.archive_path)
	if live_archive_sha.is_empty():
		return {"ok": false, "error": "The source MES ARC could not be fingerprinted before publication."}
	var reports: Array[Dictionary] = []
	var blockers: Array[String] = []
	for untyped_entry_key in _pending_text_edits_by_entry:
		var entry_name := str(untyped_entry_key).to_upper()
		var descriptor := _resolver.resolve(archive_name, entry_name)
		if not descriptor.get("ok", false):
			return {"ok": false, "error": "%s policy resolve failed: %s" % [entry_name, descriptor.error]}
		var source_data := _resolver.read_resolved(descriptor)
		if source_data.is_empty() and not _resolver.last_error.is_empty():
			return {"ok": false, "error": "%s policy read failed: %s" % [entry_name, _resolver.last_error]}
		var document := _parser.parse(source_data)
		if not document.get("ok", false):
			return {"ok": false, "error": "%s policy parse failed: %s" % [entry_name, document.error]}
		var analysis := _analysis_builder.build(document)
		if not analysis.get("ok", false):
			return {"ok": false, "error": "%s policy analysis failed: %s" % [entry_name, analysis.error]}
		var messages := {}
		for value in analysis.messages:
			messages[int(value.source_offset)] = value
		var current_source := {
			"archive": archive_name, "entry": entry_name,
			"archive_sha256": live_archive_sha,
			"entry_sha256": OverlayPackageScript.sha256_bytes(source_data),
		}
		var pending: Dictionary = _pending_text_edits_by_entry[untyped_entry_key]
		for untyped_offset in pending:
			var offset := int(untyped_offset)
			if not messages.has(offset):
				return {"ok": false, "error": "%s:0x%X is no longer a strict-indexed message." % [entry_name, offset]}
			var edit: Dictionary = pending[untyped_offset]
			var report := _text_output_policy.assess(current_source, messages[offset], {
				"source_archive_sha256": str(edit.get("source_archive_sha256", "")),
				"source_entry_sha256": str(edit.get("source_entry_sha256", "")),
				"source_offset": offset,
				"raw_sha256": str(edit.get("raw_sha256", "")),
				"text": str(edit.get("text", "")),
			})
			if not report.get("ok", false):
				return {"ok": false, "error": "%s:0x%X policy failed: %s" % [entry_name, offset, report.error]}
			reports.append(report)
			var target: Dictionary = report.targets[target_name]
			for code in target.blockers:
				blockers.append("%s:0x%X:%s" % [entry_name, offset, str(code)])
	return {
		"ok": true, "ready": blockers.is_empty(), "target": target_name,
		"compatibility": (
			"remake_only" if target_name == "remake_utf8_overlay"
			else "original_engine_unverified"
		),
		"reports": reports, "blockers": blockers,
	}


func _output_policy_refusal(action: String, result: Dictionary) -> String:
	if not result.get("ok", false):
		return "%s stopped before publication: %s" % [
			action, str(result.get("error", "policy failed")),
		]
	var blockers: Array = result.get("blockers", [])
	for blocker in blockers:
		if str(blocker).ends_with(":stale_source"):
			return "%s stopped because the source ARC changed after it was opened; pending edits were retained." % action
	return "%s blocked by %s; pending edits were retained." % [
		action, ", ".join(blockers),
	]


func _pending_for_selected() -> Dictionary:
	if _selected_entry_name.is_empty():
		return {}
	return _pending_text_edits_by_entry.get(_selected_entry_name.to_upper(), {})


func _pending_count_total() -> int:
	var total := 0
	for untyped_entry_key in _pending_text_edits_by_entry:
		var pending: Dictionary = _pending_text_edits_by_entry[untyped_entry_key]
		total += pending.size()
	return total


func _has_unstaged_message_draft() -> bool:
	if not is_instance_valid(message_edit):
		return false
	var message := _message_record_at(_selected_message_offset)
	if not _message_is_authorable(message):
		return false
	var projection := _projection_for_message(message)
	var baseline := ""
	if not projection.is_empty():
		baseline = str(projection.text)
	else:
		var decoded := _decode_message_cp932(message)
		if not decoded.ok:
			return false
		baseline = str(decoded.text)
	return message_edit.text != baseline


func _reject_unstaged_draft(action: String) -> bool:
	if not _has_unstaged_message_draft():
		return false
	status_label.text = "Stage or discard the current MES text draft before %s." % action
	return true


func _pending_native_projections_match() -> bool:
	if _pending_count_total() == 0:
		return false
	for untyped_entry_key in _pending_text_edits_by_entry:
		var pending: Dictionary = _pending_text_edits_by_entry[untyped_entry_key]
		for untyped_offset in pending:
			var edit: Dictionary = pending[untyped_offset]
			if not bool(edit.get("native_stream_projection_match", false)):
				return false
	return true


func _message_record_at(offset: int) -> Dictionary:
	for untyped_message in _message_records():
		var message: Dictionary = untyped_message
		if int(message.source_offset) == offset:
			return message
	return {}


func _update_message_edit_controls() -> void:
	_sync_run_event_player_button()
	_sync_translation_catalog_controls()
	if not is_instance_valid(message_edit):
		return
	var message := _message_record_at(_selected_message_offset)
	var editable := _message_is_authorable(message)
	message_edit.editable = editable
	message_stage_button.disabled = not editable
	var pending := _pending_for_selected()
	message_revert_button.disabled = _selected_message_offset < 0 or not pending.has(_selected_message_offset)
	var has_draft := _has_unstaged_message_draft()
	overlay_detach_button.disabled = _overlay_root.is_empty() or _overlay_messages.is_empty() or not pending.is_empty() or has_draft
	var total_pending := _pending_count_total()
	overlay_save_button.disabled = total_pending == 0 or has_draft
	binary_overlay_save_button.disabled = total_pending == 0 or not _pending_native_projections_match() or has_draft
	binary_arc_export_button.disabled = total_pending == 0 or not _pending_native_projections_match() or has_draft
	_refresh_binary_patch_status()
	_update_overlay_action_controls()
	pending_label.text = "%d here / %d total" % [pending.size(), total_pending]


func _update_overlay_action_controls() -> void:
	if not is_instance_valid(hot_reload_overlay_button) or not is_instance_valid(clear_overlay_button):
		return
	var blocked := not _reader.is_open() or _pending_count_total() > 0 or _has_unstaged_message_draft()
	hot_reload_overlay_button.disabled = _overlay_root.is_empty() or blocked
	clear_overlay_button.disabled = _overlay_root.is_empty() or blocked


func _refresh_binary_patch_status() -> void:
	if not is_instance_valid(binary_patch_label):
		return
	var total_pending := _pending_count_total()
	var message := _message_record_at(_selected_message_offset)
	if message.is_empty() or bool(message.get("projection_only", false)):
		binary_patch_label.text = "CP932: select indexed message · %d pending · engine unverified" % total_pending
		binary_patch_label.tooltip_text = "Binary editing is limited to strict-indexed source messages."
		return
	var decoded := _decode_message_cp932(message)
	if not bool(decoded.ok):
		binary_patch_label.text = "CP932: native bytes diagnostic · not editable dialogue · binary outputs disabled"
		binary_patch_label.tooltip_text = "Raw bytes are retained for analysis, but do not form valid CP932 dialogue: %s" % str(decoded.get("error", "invalid sequence"))
		return
	var report := _selected_output_policy_report(message)
	if not report.get("ok", false):
		binary_patch_label.text = "UTF-8/CP932 policy unavailable · %d pending" % total_pending
		binary_patch_label.tooltip_text = str(report.get("error", "Output policy failed."))
		return
	var remake: Dictionary = report.targets.remake_utf8_overlay
	var cp932: Dictionary = report.targets.original_cp932_candidate
	var cp932_summary := "not eligible"
	if "native_boundary_mismatch" in cp932.blockers:
		cp932_summary = "native boundary mismatch · binary outputs disabled"
	elif "byte_length_overflow" in cp932.blockers or "byte_length_underflow" in cp932.blockers:
		cp932_summary = "%d/%d bytes · exact length required" % [
			int(cp932.output_byte_count), int(cp932.source_byte_count),
		]
	elif str(cp932.status) == "ready":
		cp932_summary = "eligible %d/%d bytes" % [
			int(cp932.output_byte_count), int(cp932.source_byte_count),
		]
	binary_patch_label.text = "UTF-8: remake_only %s · CP932: %s · original_engine_unverified · %d pending" % [
		str(remake.status), cp932_summary, total_pending,
	]
	var lines: Array[String] = [
		"UTF-8 projection: %s · remake_only" % str(remake.status),
		"CP932 binary candidate: %s · original_engine_unverified" % str(cp932.status),
	]
	for diagnostic in report.diagnostics:
		lines.append("%s [%s]: %s" % [
			str(diagnostic.code), str(diagnostic.target), str(diagnostic.detail),
		])
	binary_patch_label.tooltip_text = "\n".join(lines)


func _selected_output_policy_report(message: Dictionary) -> Dictionary:
	var live_archive_sha := FileAccess.get_sha256(_reader.archive_path)
	if live_archive_sha.is_empty():
		return {"ok": false, "error": "The source MES ARC could not be fingerprinted."}
	var pending: Dictionary = _pending_for_selected()
	var retained: Dictionary = pending.get(_selected_message_offset, {})
	return _text_output_policy.assess({
		"archive": _reader.archive_path.replace("\\", "/").get_file(),
		"entry": _selected_entry_name,
		"archive_sha256": live_archive_sha,
		"entry_sha256": str(_document.get("entry_sha256", "")),
	}, message, {
		"source_archive_sha256": str(retained.get("source_archive_sha256", _archive_sha256)),
		"source_entry_sha256": str(retained.get("source_entry_sha256", _document.get("entry_sha256", ""))),
		"source_offset": _selected_message_offset,
		"raw_sha256": str(retained.get("raw_sha256", message.get("raw_sha256", ""))),
		"text": message_edit.text,
	})


func _message_native_projection_matches(message: Dictionary) -> bool:
	return bool(message.get("native_stream_projection_match", false))


func _decode_message_cp932(message: Dictionary) -> Dictionary:
	var raw_value = message.get("raw_bytes", null)
	if not raw_value is PackedByteArray:
		return {"ok": false, "error": "No original bytes.", "offset": -1}
	return _cp932.decode(raw_value)


func _message_is_authorable(message: Dictionary) -> bool:
	return (
		not message.is_empty()
		and not bool(message.get("projection_only", false))
		and bool(_decode_message_cp932(message).ok)
	)


func _populate_message_edit() -> void:
	var message := _message_record_at(_selected_message_offset)
	if message.is_empty():
		message_edit.text = ""
		message_edit.placeholder_text = "Select an indexed message to author a UTF-8 overlay edit."
		_update_message_edit_controls()
		return
	var projection := _projection_for_message(message)
	if not projection.is_empty():
		message_edit.text = str(projection.text)
	else:
		var decoded := _decode_message_cp932(message)
		message_edit.text = str(decoded.text) if decoded.ok else ""
	message_edit.placeholder_text = (
		"Enter remake-only UTF-8 replacement text."
		if _message_is_authorable(message)
		else "Native presentation bytes are diagnostic-only, not editable dialogue."
	)
	_update_message_edit_controls()


func _rebuild_reference_trees() -> void:
	code_reference_tree.clear()
	state_reference_tree.clear()
	resource_reference_tree.clear()
	var code_root := code_reference_tree.create_item()
	var state_root := state_reference_tree.create_item()
	var resource_root := resource_reference_tree.create_item()
	if not _analysis.get("ok", false):
		return
	for reference in _analysis.code_references:
		var item := code_reference_tree.create_item(code_root)
		item.set_text(0, "0x%08X" % int(reference.source_offset))
		item.set_text(1, str(reference.kind))
		item.set_text(2, "0x%08X" % int(reference.target_offset))
		item.set_text(3, "%s / %s" % [reference.target_region, "indexed" if reference.aligned else "unresolved"])
		item.set_metadata(0, int(reference.target_offset))
	for reference in _analysis.state_references:
		var item := state_reference_tree.create_item(state_root)
		item.set_text(0, "0x%08X" % int(reference.source_offset))
		item.set_text(1, str(reference.access))
		item.set_text(2, "%s[%d]" % [reference.storage, int(reference.bank)])
		item.set_text(3, "%s / x%d" % [reference.index, int(reference.count)])
		item.set_metadata(0, int(reference.source_offset))
	for reference in _analysis.resource_references:
		var item := resource_reference_tree.create_item(resource_root)
		item.set_text(0, "0x%08X" % int(reference.source_offset))
		item.set_text(1, str(reference.resource_kind))
		item.set_text(2, str(reference.name))
		item.set_text(3, "%s / %s / %s" % [
			", ".join(PackedStringArray(reference.archive_candidates)),
			str(reference.boundary),
			str(reference.native_semantics),
		])
		item.set_tooltip_text(2, "Original spelling: %s" % str(reference.source_name))
		item.set_metadata(0, int(reference.source_offset))


func _on_address_selected() -> void:
	var item := address_tree.get_selected()
	if item != null:
		_show_selected_address(item)


func _show_selected_address(item: TreeItem, record_history := true) -> void:
	if _document.is_empty():
		return
	var range_data: Dictionary = item.get_metadata(0)
	var start := int(range_data.offset)
	if record_history and not _history_navigation_active:
		_record_navigation(start)
	var end := mini(int(range_data.end_offset), start + HEX_PREVIEW_BYTES)
	var bytes: PackedByteArray = _document.bytecode
	var lines: Array[String] = []
	var cursor := start
	var instruction_count := 0
	while cursor < int(range_data.end_offset) and instruction_count < DISASSEMBLY_LIMIT:
		var instruction := _decoder.decode_at(bytes, cursor, int(range_data.end_offset))
		if not instruction.ok:
			lines.append("%08X  !! %s" % [cursor, str(instruction.error)])
			break
		var raw_hex := str(instruction.raw_hex)
		if raw_hex.length() > 32:
			raw_hex = raw_hex.substr(0, 32) + "..."
		lines.append("%08X  %02X  %-28s %-20s %s" % [
			cursor,
			int(instruction.command_id),
			str(instruction.op),
			_instruction_operand_summary(instruction),
			raw_hex,
		])
		cursor = int(instruction.end_offset)
		instruction_count += 1
	if instruction_count >= DISASSEMBLY_LIMIT and cursor < int(range_data.end_offset):
		lines.append("... disassembly limited to %d instructions" % DISASSEMBLY_LIMIT)
	lines.append("")
	lines.append("Raw byte preview:")
	for row_offset in range(start, end, 16):
		var row_end := mini(end, row_offset + 16)
		var values: Array[String] = []
		for index in range(row_offset, row_end):
			values.append("%02X" % bytes[index])
		lines.append("%08X  %s" % [row_offset, " ".join(values)])
	if end < int(range_data.end_offset):
		lines.append("... preview limited to %d bytes" % HEX_PREVIEW_BYTES)
	hex_preview.text = "\n".join(lines)
	_rebuild_cfg_graph(start, int(range_data.end_offset))


func _instruction_operand_summary(instruction: Dictionary) -> String:
	if str(instruction.get("op", "")) == "surface_dispatch_unresolved":
		var dispatch_operand: Dictionary = instruction.get("operands", [{}])[0]
		var mode_label := str(dispatch_operand.get("mode", -1))
		if str(dispatch_operand.get("mode_source", "")) != "literal":
			mode_label = "native default unresolved"
		return "mode %s ﾂｷ %d records ﾂｷ native effects omitted" % [
			mode_label,
			int(dispatch_operand.get("record_count", 0)),
		]
	if str(instruction.get("op", "")) == "surface_operation":
		var surface_operand: Dictionary = instruction.get("operands", [{}])[0]
		return "mode %d · %s · native pixels omitted" % [
			int(surface_operand.get("mode", -1)),
			str(surface_operand.get("native_operation_semantics", "surface operation")),
		]
	if str(instruction.get("op", "")) == "surface_display_refresh":
		var refresh_operand: Dictionary = instruction.get("operands", [{}])[0]
		return "mode %d · conditional attached-display refresh · native host effect omitted" % int(
			refresh_operand.get("mode", -1)
		)
	if str(instruction.get("op", "")) == "named_state_transfer":
		var transfer_operand: Dictionary = instruction.get("operands", [{}])[0]
		return "selector %d · offsets %s · host state required" % [
			int(transfer_operand.get("transfer_selector", -1)),
			str(transfer_operand.get("mapping_string", "?")),
		]
	if str(instruction.get("op", "")) == "inline_script_execution":
		var script_operand: Dictionary = instruction.get("operands", [{}])[0]
		return "%s · selector %d · %s" % [
			str(script_operand.get("name", "unknown script")),
			int(script_operand.get("execution_selector", -1)),
			str(script_operand.get("execution_role", "unknown role")),
		]
	if str(instruction.get("op", "")) == "ax_presentation_binding":
		var binding_operand: Dictionary = instruction.get("operands", [{}])[0]
		return "AX buffer -> consumer %d cell (%d,%d) ﾂｷ native bind only" % [
			int(binding_operand.get("consumer_index", -1)),
			int(binding_operand.get("cell_row", -1)),
			int(binding_operand.get("cell_column", -1)),
		]
	match int(instruction.get("command_id", -1)):
		0x0B:
			return "false -> 0x%X" % int(instruction.operands[1].value)
		0x0C:
			return "-> 0x%X" % int(instruction.operands[0].value)
		0x10:
			var definition_id := _literal_record_operand(instruction)
			var target_bytes: Array = instruction.operands[1].value
			var target := int(target_bytes[0]) | (int(target_bytes[1]) << 8) | (int(target_bytes[2]) << 16) | (int(target_bytes[3]) << 24)
			return "DEF %s -> 0x%X" % [definition_id, target]
		0x11:
			return "DEF %s" % _literal_record_operand(instruction)
		0x17:
			return "entry %d" % int(instruction.operands[0].value)
		0x1B:
			return "vector %s" % _literal_record_operand(instruction)
		0x1D:
			return "routine %s" % _literal_record_operand(instruction)
		0x1F:
			return "line %d" % int(instruction.operands[0].value)
		_:
			return ""


func _literal_record_operand(instruction: Dictionary) -> String:
	if instruction.get("operands", []).is_empty():
		return "?"
	var records: Array = instruction.operands[0].get("records", [])
	if records.size() != 1 or str(records[0].get("type", "")) != "expression_record":
		return "?"
	var ast: Dictionary = records[0].get("value", {}).get("ast", {})
	return str(ast.get("value")) if str(ast.get("type", "")) == "literal" else "dynamic"


func _on_message_selected() -> void:
	var item := message_tree.get_selected()
	if item != null:
		_selected_message_offset = int(item.get_metadata(0))
		_select_address_for_offset(_selected_message_offset, false)
		_populate_message_edit()


func _on_code_reference_selected() -> void:
	var item := code_reference_tree.get_selected()
	if item != null:
		_select_address_for_offset(int(item.get_metadata(0)), true)


func _on_state_reference_selected() -> void:
	var item := state_reference_tree.get_selected()
	if item != null:
		_select_address_for_offset(int(item.get_metadata(0)), true)


func _on_resource_reference_selected() -> void:
	var item := resource_reference_tree.get_selected()
	if item != null:
		_select_address_for_offset(int(item.get_metadata(0)), true)


func _on_cfg_node_selected(node: Node) -> void:
	if _cfg_selecting_programmatically:
		return
	if node != null and node.has_meta("code_offset"):
		_cfg_selected_node_id = str(node.name)
		cfg_focus_button.disabled = false
		var offset := int(node.get_meta("code_offset"))
		if _select_address_for_offset(offset, false):
			status_label.text = "CFG node selected at code-relative 0x%X" % offset


func _select_address_for_offset(offset: int, switch_to_disassembly: bool, record_history := true) -> bool:
	var root := address_tree.get_root()
	if root == null:
		return false
	var item := root.get_first_child()
	while item != null:
		var range_data: Dictionary = item.get_metadata(0)
		if offset >= int(range_data.offset) and offset < int(range_data.end_offset):
			item.select(0)
			address_tree.scroll_to_item(item)
			_show_selected_address(item, record_history)
			if switch_to_disassembly:
				analysis_tabs.current_tab = 0
			return true
		item = item.get_next()
	return false


func _on_cfg_back_pressed() -> void:
	_navigate_history(-1)


func _on_cfg_forward_pressed() -> void:
	_navigate_history(1)


func _on_cfg_filter_toggled(_enabled: bool) -> void:
	_render_cfg_graph()


func _on_cfg_focus_pressed() -> void:
	if _cfg_selected_node_id.is_empty():
		status_label.text = "Select a visible CFG node before focusing it."
		return
	var selected := cfg_graph.get_node_or_null(NodePath(_cfg_selected_node_id))
	if not selected is GraphNode:
		status_label.text = "The selected CFG node is hidden by the current filters."
		return
	var graph_node: GraphNode = selected
	_cfg_selecting_programmatically = true
	graph_node.selected = true
	_cfg_selecting_programmatically = false
	cfg_graph.scroll_offset = graph_node.position_offset + graph_node.size * 0.5 - cfg_graph.size * 0.5
	status_label.text = "Focused CFG node %s." % _cfg_selected_node_id


func _on_cfg_export_pressed() -> void:
	if _cfg_graph_data.is_empty():
		status_label.text = "Build a CFG before exporting it."
		return
	var range_start := int(_cfg_graph_data.range_start)
	cfg_export_dialog.current_file = "%s_%08X.cfg.json" % [_selected_entry_name.get_basename(), range_start]
	cfg_export_dialog.popup_centered_ratio(0.75)


func _on_cfg_export_path_selected(path: String) -> void:
	if _cfg_graph_data.is_empty():
		status_label.text = "CFG export stopped because no graph is available."
		return
	var extension := path.get_extension().to_lower()
	var contents := ""
	if extension == "json":
		contents = JSON.stringify(_build_cfg_export_document(), "  ") + "\n"
	elif extension == "dot":
		contents = _build_cfg_dot(_visible_cfg_projection())
	else:
		status_label.text = "CFG export requires a new .json or .dot path."
		return
	var written := _write_new_text_file(path, contents)
	status_label.text = "Exported CFG projection: %s" % path if written.ok else "CFG export failed: %s" % written.error


func _navigate_history(delta: int) -> void:
	var target_index := _navigation_index + delta
	if target_index < 0 or target_index >= _navigation_history.size():
		return
	var previous_index := _navigation_index
	_navigation_index = target_index
	_history_navigation_active = true
	var selected := _select_address_for_offset(_navigation_history[target_index], false, false)
	_history_navigation_active = false
	if not selected:
		_navigation_index = previous_index
	_update_navigation_buttons()
	if selected:
		status_label.text = "CFG navigation %d/%d: address range at 0x%X" % [
			_navigation_index + 1,
			_navigation_history.size(),
			_navigation_history[_navigation_index],
		]


func _record_navigation(range_offset: int) -> void:
	if _navigation_index >= 0 and _navigation_history[_navigation_index] == range_offset:
		_update_navigation_buttons()
		return
	if _navigation_index + 1 < _navigation_history.size():
		_navigation_history.resize(_navigation_index + 1)
	_navigation_history.append(range_offset)
	if _navigation_history.size() > NAVIGATION_HISTORY_LIMIT:
		_navigation_history.pop_front()
	_navigation_index = _navigation_history.size() - 1
	_update_navigation_buttons()


func _reset_navigation_history() -> void:
	_navigation_history.clear()
	_navigation_index = -1
	_history_navigation_active = false
	_update_navigation_buttons()


func _update_navigation_buttons() -> void:
	if is_instance_valid(cfg_back_button):
		cfg_back_button.disabled = _navigation_index <= 0
	if is_instance_valid(cfg_forward_button):
		cfg_forward_button.disabled = _navigation_index < 0 or _navigation_index + 1 >= _navigation_history.size()


func _clear_analysis_views() -> void:
	address_tree.clear()
	message_tree.clear()
	code_reference_tree.clear()
	state_reference_tree.clear()
	resource_reference_tree.clear()
	details.text = "Select an entry to inspect its lossless MES container and strict structural projections."
	hex_preview.text = ""
	_selected_message_offset = -1
	if is_instance_valid(message_edit):
		message_edit.text = ""
		_update_message_edit_controls()
	_clear_cfg_graph()
	_cfg_graph_data.clear()
	_cfg_selected_node_id = ""
	_cfg_selecting_programmatically = false
	if is_instance_valid(cfg_focus_button):
		cfg_focus_button.disabled = true
	_reset_navigation_history()
	cfg_summary.text = "Select an address range to build a bounded partial graph."


func _rebuild_cfg_graph(start_offset: int, end_offset: int) -> void:
	_clear_cfg_graph()
	_cfg_graph_data.clear()
	if not _analysis.get("ok", false):
		cfg_summary.text = "No strict analysis index is available."
		return
	var graph := _analysis_builder.build_reference_graph(
		_analysis,
		start_offset,
		end_offset,
		CFG_NODE_LIMIT,
		CFG_EXPANSION_DEPTH,
		CFG_EXPANDED_REGION_LIMIT
	)
	if not graph.ok:
		cfg_summary.text = "Graph unavailable: %s" % graph.error
		return
	_cfg_graph_data = graph
	_render_cfg_graph()


func _render_cfg_graph() -> void:
	_clear_cfg_graph()
	if _cfg_graph_data.is_empty():
		return
	var visible_projection := _visible_cfg_projection()
	var visible_edges: Array = visible_projection.edges
	var visible_nodes: Array = visible_projection.nodes
	var node_index := 0
	for untyped_node in visible_nodes:
		var node_data: Dictionary = untyped_node
		var graph_node := GraphNode.new()
		graph_node.name = str(node_data.id)
		graph_node.title = "0x%08X  %s" % [int(node_data.offset), str(node_data.op)]
		graph_node.custom_minimum_size = Vector2(205, 74)
		graph_node.position_offset = Vector2((node_index % 4) * 235, floori(node_index / 4.0) * 120)
		graph_node.set_meta("code_offset", int(node_data.offset))
		var label := Label.new()
		var status := str(node_data.status)
		var graph_depth := int(node_data.get("graph_depth", 0))
		label.text = "%s\n%s / %s" % [
			str(node_data.region),
			status,
			"seed" if graph_depth == 0 else "expanded d%d" % graph_depth,
		]
		for edge in visible_edges:
			if str(edge.from_id) == str(node_data.id):
				label.text += "\n-> %s [%s]" % [edge.kind, "confirmed" if edge.confirmed_flow else "structural"]
		if node_data.has("error"):
			label.text += "\n" + str(node_data.error)
			label.tooltip_text = str(node_data.error)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		graph_node.add_child(label)
		var port_color := _cfg_status_color(status)
		graph_node.set_slot(0, true, 0, port_color, true, 0, port_color)
		cfg_graph.add_child(graph_node)
		node_index += 1
	for edge in visible_edges:
		if edge.from_id == edge.to_id:
			continue
		var connection_error := cfg_graph.connect_node(str(edge.from_id), 0, str(edge.to_id), 0)
		if connection_error != OK and connection_error != ERR_ALREADY_EXISTS:
			push_warning("Could not render CFG edge %s." % edge.kind)
	var truncation := "; truncated: %d refs, %d stops, %d ranges omitted" % [
		int(_cfg_graph_data.skipped_references),
		int(_cfg_graph_data.skipped_stops),
		_cfg_graph_data.skipped_expansion_regions.size(),
	] if _cfg_graph_data.truncated else ""
	cfg_summary.text = "%d/%d nodes / %d/%d edges / %d stop(s); %d reached range(s), depth <= %d%s." % [
		visible_nodes.size(),
		int(_cfg_graph_data.node_count),
		visible_edges.size(),
		int(_cfg_graph_data.edge_count),
		int(_cfg_graph_data.stop_count),
		int(_cfg_graph_data.expanded_region_count),
		int(_cfg_graph_data.expansion_depth),
		truncation,
	]


func _visible_cfg_projection() -> Dictionary:
	if _cfg_graph_data.is_empty():
		return {"nodes": [], "edges": []}
	var visible_edges: Array[Dictionary] = []
	var visible_node_ids: Dictionary = {}
	for untyped_edge in _cfg_graph_data.edges:
		var edge: Dictionary = untyped_edge
		var visible := cfg_show_confirmed.button_pressed if bool(edge.confirmed_flow) else cfg_show_structural.button_pressed
		if not visible:
			continue
		visible_edges.append(edge.duplicate(true))
		visible_node_ids[str(edge.from_id)] = true
		visible_node_ids[str(edge.to_id)] = true
	if cfg_show_stops.button_pressed:
		for untyped_node in _cfg_graph_data.nodes:
			var node_data: Dictionary = untyped_node
			if str(node_data.status) == "stop":
				visible_node_ids[str(node_data.id)] = true
	var visible_nodes: Array[Dictionary] = []
	for untyped_node in _cfg_graph_data.nodes:
		var node_data: Dictionary = untyped_node
		if visible_node_ids.has(str(node_data.id)):
			visible_nodes.append(node_data.duplicate(true))
	return {"nodes": visible_nodes, "edges": visible_edges}


func _build_cfg_export_document() -> Dictionary:
	var visible := _visible_cfg_projection()
	return {
		"schema": ContentCoreVersionScript.MES_REFERENCE_GRAPH_EXPORT_SCHEMA,
		"content_core_version": ContentCoreVersionScript.CORE_VERSION,
		"archive_sha256": _reader.get_archive_fingerprint(),
		"entry": _selected_entry_name,
		"entry_sha256": str(_document.get("entry_sha256", "")),
		"range_start": int(_cfg_graph_data.get("range_start", -1)),
		"range_end": int(_cfg_graph_data.get("range_end", -1)),
		"filters": {
			"confirmed_flow": cfg_show_confirmed.button_pressed,
			"structural": cfg_show_structural.button_pressed,
			"stops": cfg_show_stops.button_pressed,
		},
		"graph": _cfg_graph_data.duplicate(true),
		"visible": visible,
	}


func _build_cfg_dot(visible: Dictionary) -> String:
	var lines: Array[String] = [
		"digraph kakyu_mes_cfg {",
		"  rankdir=LR;",
		"  graph [label=\"%s 0x%08X..0x%08X\", labelloc=t];" % [
			_dot_escape(_selected_entry_name),
			int(_cfg_graph_data.get("range_start", 0)),
			int(_cfg_graph_data.get("range_end", 0)),
		],
	]
	for untyped_node in visible.nodes:
		var node: Dictionary = untyped_node
		var status := str(node.status)
		var color := "#f24d4d" if status == "stop" else ("#59d973" if status == "indexed" else "#f2b333")
		var label := "0x%08X %s\n%s / %s" % [int(node.offset), str(node.op), str(node.region), status]
		lines.append("  \"%s\" [label=\"%s\", color=\"%s\", shape=%s];" % [
			_dot_escape(str(node.id)),
			_dot_escape(label),
			color,
			"octagon" if status == "stop" else "box",
		])
	for untyped_edge in visible.edges:
		var edge: Dictionary = untyped_edge
		lines.append("  \"%s\" -> \"%s\" [label=\"%s\", style=%s];" % [
			_dot_escape(str(edge.from_id)),
			_dot_escape(str(edge.to_id)),
			_dot_escape(str(edge.kind)),
			"solid" if bool(edge.confirmed_flow) else "dashed",
		])
	lines.append("}")
	return "\n".join(lines) + "\n"


func _dot_escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\r", "").replace("\n", "\\n")


func _write_new_text_file(path: String, contents: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	if FileAccess.file_exists(absolute):
		return {"ok": false, "error": "Output already exists; choose a new path."}
	var parent := absolute.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		return {"ok": false, "error": "Output directory does not exist."}
	var temporary := parent.path_join(".%s.tmp-%d-%d" % [absolute.get_file(), OS.get_process_id(), Time.get_ticks_usec()])
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not create the temporary export file."}
	file.store_string(contents)
	file.flush()
	file.close()
	var verification := FileAccess.open(temporary, FileAccess.READ)
	if verification == null or verification.get_as_text() != contents:
		if verification != null:
			verification.close()
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "Temporary export verification failed."}
	verification.close()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "Output appeared before publication; nothing was overwritten."}
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "Could not publish the verified export (error %s)." % rename_error}
	return {"ok": true, "path": absolute}


func _clear_cfg_graph() -> void:
	if not is_instance_valid(cfg_graph):
		return
	cfg_graph.clear_connections()
	for child in cfg_graph.get_children():
		if child is GraphNode:
			cfg_graph.remove_child(child)
			child.queue_free()


func _cfg_status_color(status: String) -> Color:
	match status:
		"indexed": return Color(0.35, 0.85, 0.45)
		"stop": return Color(0.95, 0.3, 0.3)
		_: return Color(0.95, 0.7, 0.2)


func _message_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var offsets: Dictionary = {}
	for untyped_message in _analysis.get("messages", []):
		var message: Dictionary = untyped_message
		records.append(message)
		offsets[int(message.source_offset)] = true
	for untyped_offset in _text_messages:
		var offset := int(untyped_offset)
		if offsets.has(offset):
			continue
		var projection: Dictionary = _text_messages[untyped_offset]
		records.append({
			"source_offset": offset,
			"end_offset": offset,
			"region": _region_for_offset(offset),
			"kind": "cache_projection",
			"raw_bytes": PackedByteArray(),
			"raw_hex": "",
			"raw_sha256": str(projection.raw_sha256),
			"projection_only": true,
		})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.source_offset) < int(right.source_offset)
	)
	return records


func _region_for_offset(offset: int) -> String:
	if _document.is_empty():
		return "unresolved"
	var bootstrap: Dictionary = _document.bootstrap
	if offset >= int(bootstrap.offset) and offset < int(bootstrap.end_offset):
		return "bootstrap"
	for entry in _document.entries:
		if offset >= int(entry.offset) and offset < int(entry.end_offset):
			return str(entry.id)
	return "unassigned"


func _short_hex(value: String, maximum: int) -> String:
	return value if value.length() <= maximum else value.substr(0, maximum) + "..."
