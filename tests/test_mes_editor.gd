extends Node

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const MesEditorScene := preload("res://tools/content_suite/apps/mes_editor.tscn")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://mes_editor_test"

var _failed := false


class CountingMesContainer extends KakyuMesContainer:
	var parse_count := 0

	func parse(data: PackedByteArray, source := {}) -> Dictionary:
		parse_count += 1
		return super.parse(data, source)


class MissingProjectionOverlayPackage extends KakyuOverlayPackage:
	func load_mes_text_projection(
		_package_root: String,
		_archive_name: String,
		_entry_name: String,
		_base_archive_sha256: String,
		_entry_sha256: String
	) -> Dictionary:
		return {
			"ok": true,
			"found": false,
			"edits": [],
			"messages": {},
		}


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT + "/mes.arc"
	var cache_root := TEST_ROOT + "/text_cache"
	var overlay_root := TEST_ROOT + "/my_mod"
	var projection_reload_root := TEST_ROOT + "/projection_reload_mod"
	var binary_reload_root := TEST_ROOT + "/binary_reload_mod"
	var catalog_overlay_root := TEST_ROOT + "/catalog_import_mod"
	var mes := _synthetic_mes()
	SyntheticArc.write_arc(archive_path, [
		{"name": "TEST.MES", "data": mes},
		{"name": "OTHER.MES", "data": mes},
		{"name": "INVALID.MES", "data": _synthetic_invalid_cp932_mes()},
	])
	_create_text_cache(cache_root, archive_path, "TEST.MES", mes)
	var pristine_archive_bytes := FileAccess.get_file_as_bytes(archive_path)
	var source_sha := FileAccess.get_sha256(archive_path)
	var run_workspace_root := TEST_ROOT + "/run_workspace"
	var run_workspace := ContentWorkspaceScript.new()
	var run_workspace_created := run_workspace.create(
		run_workspace_root, TEST_ROOT, _run_workspace_project(source_sha)
	)
	_check(run_workspace_created.get("ok", false), "MES Editor Run fixture creates a named workspace through Content Core")
	run_workspace.close()

	var editor: Control = MesEditorScene.instantiate()
	editor.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("path_history.cfg")))
	add_child(editor)
	await get_tree().process_frame
	var definition_invoke: Dictionary = editor.get("_decoder").decode_at(PackedByteArray([0x11, 0x02, 0x0B, 0xFF, 0x00]), 0)
	var routine_transfer: Dictionary = editor.get("_decoder").decode_at(PackedByteArray([0x1D, 0x02, 0x1C, 0xFF, 0x00]), 0)
	var inline_script_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x03, 0xFF, 0x01])
	inline_script_code.append_array("def_main.mes".to_ascii_buffer())
	inline_script_code.append_array(PackedByteArray([0x00, 0x00]))
	var inline_script: Dictionary = editor.get("_decoder").decode_at(inline_script_code, 0)
	var state_transfer: Dictionary = editor.get("_decoder").decode_at(PackedByteArray([
		0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF,
		0x02, 0xF8, 0x2B, 0xFF,
		0x01, 0x48, 0x54, 0x45, 0x00,
		0x00,
	]), 0)
	_check(
		editor.call("_instruction_operand_summary", definition_invoke) == "DEF 11"
		and editor.call("_instruction_operand_summary", routine_transfer) == "routine 28",
		"MES Editor disassembly summarizes confirmed DEF and shared-routine selectors"
	)
	_check(
		editor.call("_instruction_operand_summary", inline_script)
		== "DEF_MAIN.MES · selector 3 · definition_bootstrap",
		"MES Editor disassembly names the confirmed startup script target, selector, and role"
	)
	_check(
		editor.call("_instruction_operand_summary", state_transfer)
		== "selector 13 · offsets HTE · host state required",
		"MES Editor disassembly names the confirmed native relative-offset transfer boundary"
	)
	editor.call("_open_archive", archive_path)
	_check(str(editor.get("_archive_sha256")) == source_sha, "MES Editor pins the source ARC fingerprint when opening its index")
	_check((editor.get("_path_history") as ContentToolPathHistory).get_last_source_directory() == absolute_root.simplify_path(), "MES Editor remembers its successfully opened ARC directory")
	_check((editor.get_node("OpenDialog") as FileDialog).current_dir.simplify_path() == absolute_root.simplify_path(), "MES Editor reopens its ARC chooser at the remembered directory")
	_check(get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "MES Editor uses native desktop pixels")
	_check(editor.size == Vector2(get_window().size), "MES Editor fills the desktop client area")
	_check(editor.theme != null and editor.theme.default_font_size == 11, "MES Editor uses a compact tool-specific font size")
	_check(_controls_fit(editor), "MES Editor controls fit the desktop client area")
	var toolbar: HBoxContainer = editor.get_node("Margin/Layout/Toolbar")
	var hot_reload_overlay_button: Button = editor.get_node("Margin/Layout/Toolbar/HotReloadOverlay")
	var clear_overlay_button: Button = editor.get_node("Margin/Layout/Toolbar/ClearOverlay")
	var right_panel: VBoxContainer = editor.get_node("Margin/Layout/MainSplit/Right")
	var authoring_row: HBoxContainer = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring")
	var binary_patch_row: HBoxContainer = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar")
	var catalog_bar: HFlowContainer = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/CatalogBar")
	_check(toolbar.get_combined_minimum_size().x <= toolbar.size.x, "MES Editor toolbar text fits the desktop layout")
	_check(
		hot_reload_overlay_button.text.contains("Hot Reload")
		and clear_overlay_button.text.contains("Clear")
		and hot_reload_overlay_button.disabled
		and clear_overlay_button.disabled,
		"MES Editor exposes the shared overlay Hot Reload and Clear actions"
	)
	_check(authoring_row.get_combined_minimum_size().x <= right_panel.size.x, "MES Editor message authoring row fits its desktop panel")
	_check(binary_patch_row.get_combined_minimum_size().x <= right_panel.size.x, "MES Editor CP932 binary row fits its desktop panel")
	_check(catalog_bar.get_combined_minimum_size().x <= right_panel.size.x, "MES Editor translation catalog controls fit their desktop panel")
	var original_window_size := get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_check(editor.size == Vector2(1920, 1080), "MES Editor reflows at 1920x1080")
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(
		editor.size == Vector2(1024, 640)
		and _controls_fit(editor)
		and toolbar.get_combined_minimum_size().x <= toolbar.size.x,
		"MES Editor overlay toolbar and analysis controls fit the shared minimum desktop size"
	)
	get_window().size = original_window_size
	await get_tree().process_frame

	var entry_tree: Tree = editor.get_node("Margin/Layout/MainSplit/EntryTree")
	var entry_item := entry_tree.get_root().get_first_child()
	entry_item.select(0)
	editor.call("_on_entry_selected")
	var message_tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageTree")
	var first_original_message := message_tree.get_root().get_first_child()
	first_original_message.select(0)
	editor.call("_on_message_selected")
	var message_edit: LineEdit = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/MessageEdit")
	_check(message_edit.text == "HELLO", "message authoring starts from decoded original CP932 without requiring a cache")
	_check(first_original_message.get_text(1).contains("native boundary mismatch"), "MES Editor marks a text projection that crosses the EXE-matched native boundary")
	_check(message_edit.editable, "native boundary mismatch remains editable through the remake-only UTF-8 overlay path")
	_check(
		(editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryPatchLabel") as Label).text.contains("binary outputs disabled"),
		"MES Editor distinguishes remake-only UTF-8 editing from unsafe binary output"
	)
	var launch_context = editor.get("_launch_context")
	var run_activation: Dictionary = launch_context.activate(PackedStringArray([
		"--content-set", TEST_ROOT, "--workspace", run_workspace_root,
		"--archive", archive_path,
	]))
	_check(run_activation.get("ok", false), "MES Editor Run fixture activates the named workspace")
	editor.call("_sync_run_event_player_button")
	editor.call("_sync_translation_catalog_controls")
	var run_button: Button = editor.get_node("Margin/Layout/Toolbar/RunEventPlayer")
	var catalog_export_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/CatalogBar/CatalogExportButton")
	var catalog_update_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/CatalogBar/CatalogUpdateButton")
	var catalog_import_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/CatalogBar/CatalogImportButton")
	_check(not run_button.disabled, "MES Editor enables Run for a parsed entry in an active named workspace")
	_check(
		not catalog_export_button.disabled and catalog_update_button.disabled
		and not catalog_import_button.disabled,
		"MES Editor enables exact-source Catalog Export/Import before staging translations"
	)
	var translation_catalog: Dictionary = editor.call("_build_selected_translation_catalog")
	_check(
		translation_catalog.get("ok", false) and translation_catalog.rows.size() == 2
		and not JSON.stringify(translation_catalog).contains("HELLO"),
		"MES Editor exports selected-entry translation identities without original dialogue"
	)
	var translation_path := run_workspace_root + "/test.translation.json"
	var translation_published: Dictionary = editor.call(
		"_publish_translation_catalog", translation_path, translation_catalog
	)
	if not translation_published.get("ok", false):
		push_error("Translation catalog publication fixture failed: " + str(translation_published))
	_check(
		translation_published.get("ok", false) and FileAccess.file_exists(translation_path)
		and not editor.call("_publish_translation_catalog", translation_path, translation_catalog).get("ok", false),
		"MES Editor atomically publishes a new catalog inside the workspace without overwrite"
	)
	_check(
		not editor.call("_publish_translation_catalog", TEST_ROOT + "/outside.translation.json", translation_catalog).get("ok", false),
		"MES Editor refuses to publish a translation catalog outside the active workspace"
	)
	var outside_translation_path := TEST_ROOT + "/outside.translation.json"
	_write_json(outside_translation_path, translation_catalog)
	_check(
		not editor.call("_load_translation_catalog", outside_translation_path).get("ok", false),
		"MES Editor refuses to load a translation catalog from outside the active workspace"
	)
	message_edit.text = "TRANSLATED"
	editor.call("_on_stage_text_pressed")
	(editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/CatalogBar/CatalogTranslatorId") as LineEdit).text = "translator.test"
	var catalog_updated: Dictionary = editor.call("_prepare_translation_catalog_update", translation_catalog)
	_check(
		catalog_updated.get("ok", false)
		and int(catalog_updated.catalog.catalog.catalog_revision) == 2
		and str(catalog_updated.catalog.rows[0].translation.text) == "TRANSLATED"
		and not catalog_update_button.disabled and catalog_export_button.disabled,
		"MES Editor updates staged translations as a new catalog revision with provenance"
	)
	var translated_path := run_workspace_root + "/test.r2.translation.json"
	var updated_published: Dictionary = editor.call(
		"_publish_translation_catalog", translated_path, catalog_updated.catalog
	)
	if not updated_published.get("ok", false):
		push_error("Updated translation catalog publication fixture failed: " + str(updated_published))
	_check(
		updated_published.get("ok", false),
		"MES Editor publishes and reopens the updated translation catalog"
	)
	editor.set("_pending_text_edits_by_entry", {})
	editor.call("_rebuild_message_tree")
	editor.call("_populate_message_edit")
	var catalog_imported: Dictionary = editor.call("_import_translation_catalog", translated_path)
	var imported_offset := int(catalog_updated.catalog.rows[0].source_offset)
	_check(
		catalog_imported.get("ok", false) and int(catalog_imported.edit_count) == 1
		and str(editor.call("_pending_for_selected")[imported_offset].text) == "TRANSLATED",
		"MES Editor imports an exact catalog as hash-bound pending UTF-8 edits"
	)
	editor.call("_on_overlay_save_selected", catalog_overlay_root)
	_check(
		editor.call("_pending_count_total") == 0
		and str(editor.get("_document").source.resolved_source) == "original_arc"
		and message_tree.get_root().get_first_child().get_text(2) == "TRANSLATED"
		and FileAccess.get_sha256(archive_path) == source_sha,
		"catalog-imported translations publish through the existing UTF-8 overlay batch without changing MES bytes"
	)
	editor.call("_on_clear_overlay_pressed")
	_check(
		str(editor.get("_document").source.resolved_source) == "original_arc"
		and message_tree.get_root().get_first_child().get_text(2) == "HELLO",
		"clearing the catalog-imported projection restores original dialogue"
	)
	first_original_message = message_tree.get_root().get_first_child()
	first_original_message.select(0)
	editor.call("_on_message_selected")
	var run_path := TEST_ROOT + "/requests/test.run.json"
	var run_result: Dictionary = editor.call("_publish_run_request", run_path, "code_offset", 0, {})
	if not run_result.ok:
		push_error("MES Editor Run fixture failed: " + str(run_result.get("error", "unknown")))
	var run_document = (
		JSON.parse_string(FileAccess.get_file_as_string(run_path))
		if FileAccess.file_exists(run_path) else null
	)
	_check(
		run_result.ok and run_document is Dictionary
		and str(run_document.schema) == "kakyu_mes_editor_run_request/v1"
		and str(run_document.content.entry) == "TEST.MES"
		and str(run_document.interface.kind) == "exact_original"
		and int(run_document.launch.start_value) == 0,
		"MES Editor publishes a path-free exact-original Analysis Run request"
	)
	var run_launch: Dictionary = editor.call("_build_event_player_run_arguments", run_path, "")
	var run_arguments: PackedStringArray = run_launch.get("arguments", PackedStringArray())
	_check(
		run_launch.get("ok", false)
		and run_arguments.has("res://tools/content_suite/apps/event_player.tscn")
		and run_arguments.has("--content-set")
		and run_arguments.has("--workspace")
		and run_arguments.has("--run-request")
		and run_arguments.has(ProjectSettings.globalize_path(run_path).simplify_path())
		and not run_arguments.has("--interface-proof"),
		"MES Editor builds an independent Event Player launch with workspace and immutable Run request inputs"
	)
	var proof_launch: Dictionary = editor.call("_build_event_player_run_arguments", run_path, run_path)
	var proof_arguments: PackedStringArray = proof_launch.get("arguments", PackedStringArray())
	_check(
		proof_launch.get("ok", false)
		and proof_arguments.count("--run-request") == 1
		and proof_arguments.count("--interface-proof") == 0,
		"MES Editor never emits an interface proof even when a proof path argument is supplied"
	)
	_check(
		not editor.call("_publish_run_request", run_path, "code_offset", 0, {}).ok,
		"MES Editor Run publication refuses to replace an existing request"
	)
	message_edit.text = "UNSTAGED"
	editor.call("_sync_run_event_player_button")
	_check(
		not editor.call("_publish_run_request", TEST_ROOT + "/requests/draft.run.json", "code_offset", 0, {}).ok
		and not FileAccess.file_exists(TEST_ROOT + "/requests/draft.run.json")
		and run_button.disabled,
		"MES Editor Run blocks and disables launch for an unstaged draft without publishing a request"
	)
	message_edit.text = "HELLO"
	editor.call("_sync_run_event_player_button")
	_check(not run_button.disabled, "MES Editor restores Run after the unstaged draft is discarded")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "MES Editor Run request publication leaves the source ARC unchanged")
	var invalid_entry := entry_item.get_next().get_next()
	invalid_entry.select(0)
	editor.call("_on_entry_selected")
	var invalid_message := message_tree.get_root().get_first_child()
	invalid_message.select(0)
	editor.call("_on_message_selected")
	var invalid_stage_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/MessageStageButton")
	var invalid_patch_label: Label = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryPatchLabel")
	_check(invalid_message.get_text(2) == "Native presentation bytes (not CP932 dialogue)", "MES Editor separates invalid native pairs from human-readable dialogue")
	_check(invalid_message.get_tooltip_text(2).contains("Raw bytes (hex): 8f01"), "MES Editor keeps invalid native bytes in the diagnostic tooltip")
	_check(not message_edit.editable and invalid_stage_button.disabled, "invalid native pairs are read-only analysis evidence")
	editor.call("_on_stage_text_pressed")
	_check(editor.call("_pending_count_total") == 0 and (editor.get_node("Margin/Layout/StatusLabel") as Label).text.contains("diagnostic-only"), "MES Editor refuses to stage invalid native pairs as authored dialogue")
	_check(invalid_patch_label.text.contains("native bytes diagnostic"), "MES Editor reports why invalid native pairs cannot use binary output")
	entry_item.select(0)
	editor.call("_on_entry_selected")

	var overlay_package := OverlayPackageScript.new()
	var overlay_source := ArcReaderScript.new()
	_check(overlay_source.open(archive_path), "MES overlay reload fixtures reopen the synthetic source ARC")
	var first_binary_reload_mes := _replace_ascii(mes, 13, "ALPHA")
	var first_binary_reload := overlay_package.stage_replacement(
		binary_reload_root,
		overlay_source,
		"mes.arc",
		"TEST.MES",
		first_binary_reload_mes,
		"remake_only",
		"cp932"
	)
	_check(first_binary_reload.ok, "binary Hot Reload fixture publishes its first hash-bound MES replacement")
	var first_binary_payload_sha := FileAccess.get_sha256(str(first_binary_reload.replacement_path))
	editor.call("_on_overlay_load_selected", binary_reload_root)
	_check(
		str(editor.get("_overlay_root")) == ProjectSettings.globalize_path(binary_reload_root).simplify_path()
		and str(editor.get("_document").source.resolved_source) == "overlay"
		and str(editor.get("_document").entry_sha256) == _sha256(first_binary_reload_mes)
		and message_tree.get_root().get_first_child().get_text(2) == "ALPHA",
		"MES Editor loads and analyzes CP932 dialogue from a binary overlay replacement"
	)
	var first_binary_manifest_sha := FileAccess.get_sha256(binary_reload_root + "/manifest.json")
	var second_binary_reload_mes := _replace_ascii(mes, 13, "BRAVO")
	var second_binary_reload := overlay_package.stage_replacement(
		binary_reload_root,
		overlay_source,
		"mes.arc",
		"TEST.MES",
		second_binary_reload_mes,
		"remake_only",
		"cp932"
	)
	_check(
		second_binary_reload.ok
		and FileAccess.get_sha256(binary_reload_root + "/manifest.json") != first_binary_manifest_sha,
		"an external binary editor can atomically retarget the loaded overlay manifest"
	)
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		str(editor.get("_document").source.resolved_source) == "overlay"
		and str(editor.get("_document").entry_sha256) == _sha256(second_binary_reload_mes)
		and message_tree.get_root().get_first_child().get_text(2) == "BRAVO"
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("Hot Reload"),
		"MES Editor Hot Reload reparses changed binary MES bytes and refreshes decoded CP932 text"
	)
	editor.call("_on_clear_overlay_pressed")
	_check(
		str(editor.get("_overlay_root")).is_empty()
		and str(editor.get("_document").source.resolved_source) == "original_arc"
		and str(editor.get("_document").entry_sha256) == _sha256(mes)
		and message_tree.get_root().get_first_child().get_text(2) == "HELLO",
		"clearing a binary MES overlay reparses the unchanged original ARC entry"
	)
	_check(
		FileAccess.get_sha256(str(first_binary_reload.replacement_path)) == first_binary_payload_sha,
		"binary Hot Reload retains the superseded content-addressed payload without rewriting it"
	)

	editor.call("_configure_text_cache", cache_root)
	entry_item.select(0)
	editor.call("_on_entry_selected")
	var projection_base_replacement := overlay_package.stage_replacement(
		projection_reload_root,
		overlay_source,
		"mes.arc",
		"TEST.MES",
		mes,
		"remake_only",
		"cp932"
	)
	_check(projection_base_replacement.ok, "projection reload fixture includes an effective MES resolver layer")
	var first_projection_reload := overlay_package.stage_mes_text_projection(
		projection_reload_root,
		overlay_source,
		"mes.arc",
		"TEST.MES",
		[{
			"source_offset": 0,
			"raw_sha256": _sha256("HELLO".to_ascii_buffer()),
			"text": "External projection A",
		}]
	)
	_check(first_projection_reload.ok, "projection Hot Reload fixture publishes its first UTF-8 edit")
	editor.call("_on_overlay_load_selected", projection_reload_root)
	_check(
		str(editor.get("_overlay_root")) == ProjectSettings.globalize_path(projection_reload_root).simplify_path()
		and editor.get("_overlay_messages")[0].text == "External projection A"
		and message_tree.get_root().get_first_child().get_text(2) == "External projection A"
		and not hot_reload_overlay_button.disabled
		and not clear_overlay_button.disabled,
		"MES Editor loads a hash-bound UTF-8 projection above the configured cache"
	)
	var first_projection_manifest_sha := FileAccess.get_sha256(projection_reload_root + "/manifest.json")
	var first_projection_payload_sha := FileAccess.get_sha256(str(first_projection_reload.projection_path))
	var second_projection_reload := overlay_package.stage_mes_text_projection(
		projection_reload_root,
		overlay_source,
		"mes.arc",
		"TEST.MES",
		[{
			"source_offset": 0,
			"raw_sha256": _sha256("HELLO".to_ascii_buffer()),
			"text": "External projection B",
		}]
	)
	_check(
		second_projection_reload.ok
		and FileAccess.get_sha256(projection_reload_root + "/manifest.json") != first_projection_manifest_sha,
		"an external projection editor can atomically retarget the loaded overlay manifest"
	)
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		editor.get("_overlay_messages")[0].text == "External projection B"
		and message_tree.get_root().get_first_child().get_text(2) == "External projection B",
		"MES Editor Hot Reload reopens an externally changed UTF-8 projection"
	)
	var projection_manifest_path := projection_reload_root + "/manifest.json"
	var valid_projection_manifest_bytes := FileAccess.get_file_as_bytes(projection_manifest_path)
	var expected_projection_manifest_sha := FileAccess.get_sha256(projection_manifest_path)
	var configured_candidate: Dictionary = editor.call("_configure_loaded_overlay", projection_reload_root)
	_check(
		configured_candidate.ok
		and str(configured_candidate.get("manifest_sha256", "")) == expected_projection_manifest_sha
		and editor.call(
			"_manifest_fingerprint_is_stable",
			ProjectSettings.globalize_path(projection_reload_root).simplify_path(),
			expected_projection_manifest_sha
		),
		"overlay preflight returns the stable manifest fingerprint used by activation"
	)
	var preflight_active_root := str(editor.get("_overlay_root"))
	var preflight_active_document_sha := str(editor.get("_document").entry_sha256)
	var preflight_active_messages: Dictionary = editor.get("_overlay_messages").duplicate(true)
	var drift_projection := overlay_package.stage_mes_text_projection(
		projection_reload_root,
		overlay_source,
		"mes.arc",
		"TEST.MES",
		[{
			"source_offset": 0,
			"raw_sha256": _sha256("HELLO".to_ascii_buffer()),
			"text": "Manifest drift projection",
		}]
	)
	_check(
		drift_projection.ok
		and not editor.call(
			"_manifest_fingerprint_is_stable",
			ProjectSettings.globalize_path(projection_reload_root).simplify_path(),
			expected_projection_manifest_sha
		),
		"manifest fingerprint helper detects an external manifest change after preflight"
	)
	var drift_activation: Dictionary = editor.call("_activate_loaded_overlay", configured_candidate)
	_check(
		not drift_activation.ok
		and str(editor.get("_overlay_root")) == preflight_active_root
		and str(editor.get("_document").entry_sha256) == preflight_active_document_sha
		and editor.get("_overlay_messages") == preflight_active_messages
		and message_tree.get_root().get_first_child().get_text(2) == "External projection B",
		"overlay activation rejects manifest SHA drift without replacing the active candidate state"
	)
	_write_bytes(projection_manifest_path, valid_projection_manifest_bytes)
	editor.call("_on_hot_reload_overlay_pressed")

	var real_overlay_package = editor.get("_overlay_package")
	editor.set("_overlay_package", MissingProjectionOverlayPackage.new())
	var missing_projection_candidate: Dictionary = editor.call("_configure_loaded_overlay", projection_reload_root)
	_check(
		not missing_projection_candidate.ok
		and str(missing_projection_candidate.get("error", "")).contains("projection")
		and str(editor.get("_overlay_root")) == preflight_active_root
		and str(editor.get("_document").entry_sha256) == preflight_active_document_sha
		and editor.get("_overlay_messages") == preflight_active_messages,
		"overlay preflight rejects a manifest projection record whose projection lookup reports found=false"
	)
	if missing_projection_candidate.get("ok", false):
		missing_projection_candidate.resolver.close()
	editor.set("_overlay_package", real_overlay_package)

	var stable_overlay_root := str(editor.get("_overlay_root"))
	var stable_document_sha := str(editor.get("_document").entry_sha256)
	var stable_overlay_messages: Dictionary = editor.get("_overlay_messages").duplicate(true)
	var stable_resolver_descriptor: Dictionary = editor.get("_resolver").resolve("mes.arc", "TEST.MES")
	_write_bytes(projection_manifest_path, "{ invalid overlay manifest".to_utf8_buffer())
	editor.call("_on_hot_reload_overlay_pressed")
	var invalid_json_descriptor: Dictionary = editor.get("_resolver").resolve("mes.arc", "TEST.MES")
	_check(
		str(editor.get("_overlay_root")) == stable_overlay_root
		and str(editor.get("_document").entry_sha256) == stable_document_sha
		and editor.get("_overlay_messages") == stable_overlay_messages
		and invalid_json_descriptor == stable_resolver_descriptor
		and message_tree.get_root().get_first_child().get_text(2) == "External projection B"
		and not hot_reload_overlay_button.disabled
		and not clear_overlay_button.disabled
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("failed"),
		"invalid-JSON Hot Reload preserves the active root, document, projection, resolver, and controls"
	)
	_write_bytes(projection_manifest_path, valid_projection_manifest_bytes)

	var mismatched_base_sha := "0".repeat(64)
	var mismatch_manifest: Dictionary = JSON.parse_string(valid_projection_manifest_bytes.get_string_from_utf8())
	var mismatch_projection_record: Dictionary = mismatch_manifest.projections[0]
	var valid_projection_document_path := ProjectSettings.globalize_path(projection_reload_root).simplify_path().path_join(
		str(mismatch_projection_record.projection_path)
	)
	var mismatch_projection_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(valid_projection_document_path))
	mismatch_projection_document.base_archive_sha256 = mismatched_base_sha
	var mismatch_projection_bytes := (JSON.stringify(mismatch_projection_document, "  ") + "\n").to_utf8_buffer()
	var mismatch_projection_sha := _sha256(mismatch_projection_bytes)
	var mismatch_projection_relative := "projections/mes/%s-TEST.MES.json" % mismatch_projection_sha
	var mismatch_projection_path := ProjectSettings.globalize_path(projection_reload_root).simplify_path().path_join(
		mismatch_projection_relative
	)
	_write_bytes(mismatch_projection_path, mismatch_projection_bytes)
	mismatch_projection_record.base_archive_sha256 = mismatched_base_sha
	mismatch_projection_record.projection_sha256 = mismatch_projection_sha
	mismatch_projection_record.projection_path = mismatch_projection_relative
	mismatch_manifest.projections[0] = mismatch_projection_record
	var mismatch_replacement_record: Dictionary = mismatch_manifest.replacements[0]
	mismatch_replacement_record.base_archive_sha256 = mismatched_base_sha
	mismatch_manifest.replacements[0] = mismatch_replacement_record
	_write_json(projection_manifest_path, mismatch_manifest)
	_check(
		overlay_package.load_manifest(projection_reload_root).ok,
		"base-mismatch fixture remains structurally valid and reaches source-binding validation"
	)
	editor.call("_on_hot_reload_overlay_pressed")
	var mismatch_descriptor: Dictionary = editor.get("_resolver").resolve("mes.arc", "TEST.MES")
	_check(
		str(editor.get("_overlay_root")) == stable_overlay_root
		and str(editor.get("_document").entry_sha256) == stable_document_sha
		and editor.get("_overlay_messages") == stable_overlay_messages
		and mismatch_descriptor == stable_resolver_descriptor
		and message_tree.get_root().get_first_child().get_text(2) == "External projection B"
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("failed"),
		"base-ARC-mismatch Hot Reload rejects before replacing the active resolver or presentation state"
	)
	_write_bytes(projection_manifest_path, valid_projection_manifest_bytes)
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		editor.get("_resolver").resolve("mes.arc", "TEST.MES") == stable_resolver_descriptor
		and editor.get("_overlay_messages") == stable_overlay_messages,
		"restoring the valid manifest reopens the same effective overlay state"
	)

	var draft_message := message_tree.get_root().get_first_child()
	draft_message.select(0)
	editor.call("_on_message_selected")
	message_edit.text = "Unstaged draft"
	editor.call("_on_message_text_changed", message_edit.text)
	var draft_root := str(editor.get("_overlay_root"))
	var draft_document_sha := str(editor.get("_document").entry_sha256)
	var draft_overlay_messages: Dictionary = editor.get("_overlay_messages").duplicate(true)
	var draft_resolver_descriptor: Dictionary = editor.get("_resolver").resolve("mes.arc", "TEST.MES")
	_check(
		editor.call("_pending_count_total") == 0
		and hot_reload_overlay_button.disabled
		and clear_overlay_button.disabled,
		"an unstaged message draft disables overlay-changing toolbar actions without becoming pending"
	)
	var draft_source_path := str(editor.get("_reader").archive_path)
	var draft_source_sha := FileAccess.get_sha256(draft_source_path)
	var draft_selected_entry := str(editor.get("_selected_entry_name"))
	var draft_filter_edit: LineEdit = editor.get_node("Margin/Layout/FilterEdit")
	draft_filter_edit.text = "OTHER"
	editor.call("_on_filter_changed", draft_filter_edit.text)
	var filtered_other_entry := entry_tree.get_root().get_first_child()
	var filtered_click_available := filtered_other_entry != null
	if filtered_click_available:
		filtered_other_entry.select(0)
	for _restore_frame in range(3):
		await get_tree().process_frame
		if not bool(editor.get("_entry_selection_restore_pending")) and draft_filter_edit.text.is_empty():
			break
	var restored_filtered_selection := entry_tree.get_selected()
	var filtered_restore_ready := (
		filtered_click_available
		and not bool(editor.get("_entry_selection_restore_pending"))
		and draft_filter_edit.text.is_empty()
		and entry_tree.get_root() != null
	)
	_check(
		filtered_restore_ready
		and entry_tree.get_root().get_child_count() == 3
		and restored_filtered_selection != null
		and str(restored_filtered_selection.get_metadata(0)) == draft_selected_entry
		and str(editor.get("_selected_entry_name")) == draft_selected_entry
		and str(editor.get("_document").entry_sha256) == draft_document_sha
		and message_edit.text == "Unstaged draft"
		and FileAccess.get_sha256(draft_source_path) == draft_source_sha,
		"hidden draft entry is made visible and reselected when another filtered row is clicked"
	)
	if not filtered_restore_ready:
		editor.call("_restore_entry_tree_selection", draft_selected_entry)
		await get_tree().process_frame
	entry_item = entry_tree.get_root().get_first_child()
	var draft_other_entry := entry_item.get_next() if entry_item != null else null
	if draft_other_entry != null:
		draft_other_entry.select(0)
	for _restore_frame in range(3):
		await get_tree().process_frame
		if not bool(editor.get("_entry_selection_restore_pending")):
			break
	var draft_tree_selection := entry_tree.get_selected()
	_check(
		draft_other_entry != null
		and str(editor.get("_selected_entry_name")) == draft_selected_entry
		and str(editor.get("_document").entry_sha256) == draft_document_sha
		and message_edit.text == "Unstaged draft"
		and str(editor.get("_reader").archive_path) == draft_source_path
		and FileAccess.get_sha256(draft_source_path) == draft_source_sha,
		"MES Editor blocks entry selection without discarding an unstaged draft or changing the source ARC"
	)
	_check(
		draft_tree_selection != null
		and str(draft_tree_selection.get_metadata(0)) == draft_selected_entry
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft"),
		"blocked draft entry switch restores the visible selection and explains the guard"
	)
	if str(editor.get("_selected_entry_name")) != draft_selected_entry or message_edit.text != "Unstaged draft":
		entry_item.select(0)
		editor.call("_on_entry_selected")
		editor.call("_on_overlay_load_selected", projection_reload_root)
		draft_message = message_tree.get_root().get_first_child()
		draft_message.select(0)
		editor.call("_on_message_selected")
		message_edit.text = "Unstaged draft"
		editor.call("_on_message_text_changed", message_edit.text)
	editor.call("_open_archive", archive_path)
	_check(
		str(editor.get("_selected_entry_name")) == draft_selected_entry
		and str(editor.get("_document").entry_sha256) == draft_document_sha
		and message_edit.text == "Unstaged draft"
		and str(editor.get("_reader").archive_path) == draft_source_path
		and FileAccess.get_sha256(draft_source_path) == draft_source_sha
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft"),
		"MES Editor blocks ARC reopen without discarding an unstaged draft or replacing the active document"
	)
	if str(editor.get("_selected_entry_name")) != draft_selected_entry or message_edit.text != "Unstaged draft":
		editor.call("_configure_text_cache", cache_root)
		entry_item = entry_tree.get_root().get_first_child()
		entry_item.select(0)
		editor.call("_on_entry_selected")
		editor.call("_on_overlay_load_selected", projection_reload_root)
		draft_message = message_tree.get_root().get_first_child()
		draft_message.select(0)
		editor.call("_on_message_selected")
		message_edit.text = "Unstaged draft"
		editor.call("_on_message_text_changed", message_edit.text)
	editor.call("_on_hot_reload_overlay_pressed")
	var draft_reload_descriptor: Dictionary = editor.get("_resolver").resolve("mes.arc", "TEST.MES")
	_check(
		message_edit.text == "Unstaged draft"
		and str(editor.get("_overlay_root")) == draft_root
		and str(editor.get("_document").entry_sha256) == draft_document_sha
		and editor.get("_overlay_messages") == draft_overlay_messages
		and draft_reload_descriptor == draft_resolver_descriptor
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft"),
		"MES Editor blocks Hot Reload without discarding an unstaged draft or active overlay state"
	)
	if message_edit.text != "Unstaged draft" or str(editor.get("_overlay_root")) != draft_root:
		editor.call("_on_overlay_load_selected", projection_reload_root)
		draft_message = message_tree.get_root().get_first_child()
		draft_message.select(0)
		editor.call("_on_message_selected")
		message_edit.text = "Unstaged draft"
		editor.call("_on_message_text_changed", message_edit.text)
	editor.call("_on_clear_overlay_pressed")
	var draft_clear_descriptor: Dictionary = editor.get("_resolver").resolve("mes.arc", "TEST.MES")
	_check(
		message_edit.text == "Unstaged draft"
		and str(editor.get("_overlay_root")) == draft_root
		and str(editor.get("_document").entry_sha256) == draft_document_sha
		and editor.get("_overlay_messages") == draft_overlay_messages
		and draft_clear_descriptor == draft_resolver_descriptor
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft"),
		"MES Editor blocks Clear without discarding an unstaged draft or active overlay state"
	)
	if message_edit.text != "Unstaged draft" or str(editor.get("_overlay_root")) != draft_root:
		editor.call("_on_overlay_load_selected", projection_reload_root)
		draft_message = message_tree.get_root().get_first_child()
		draft_message.select(0)
		editor.call("_on_message_selected")
	message_edit.text = "External projection B"
	editor.call("_on_message_text_changed", message_edit.text)
	_check(
		not hot_reload_overlay_button.disabled and not clear_overlay_button.disabled,
		"restoring the loaded projection text clears the draft guard and re-enables overlay actions"
	)
	var projection_root_before_block := str(editor.get("_overlay_root"))
	var projection_manifest_before_block := FileAccess.get_sha256(projection_reload_root + "/manifest.json")
	var projection_payload_before_block := FileAccess.get_sha256(str(second_projection_reload.projection_path))
	var first_projection_message := message_tree.get_root().get_first_child()
	first_projection_message.select(0)
	editor.call("_on_message_selected")
	message_edit.text = "Pending projection"
	editor.call("_on_stage_text_pressed")
	_check(
		editor.call("_pending_count_total") == 1
		and hot_reload_overlay_button.disabled
		and clear_overlay_button.disabled,
		"MES Editor stages a pending edit above the loaded projection and disables overlay changes"
	)
	message_edit.text = "Draft after staged value"
	editor.call("_on_message_text_changed", message_edit.text)
	var draft_guard_save_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/OverlaySaveButton")
	var draft_guard_binary_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryOverlaySaveButton")
	var draft_guard_arc_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryArcExportButton")
	var draft_guard_detach_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/OverlayDetachButton")
	var draft_guard_manifest_sha := FileAccess.get_sha256(projection_reload_root + "/manifest.json")
	var draft_guard_document_sha := str(editor.get("_document").entry_sha256)
	var draft_guard_overlay_messages: Dictionary = editor.get("_overlay_messages").duplicate(true)
	var draft_guard_binary_root := TEST_ROOT + "/draft_guard_binary_mod"
	var draft_guard_arc_path := TEST_ROOT + "/draft_guard_export.arc"
	var every_draft_callback_rejected := true
	editor.call("_on_overlay_save_pressed")
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	editor.call("_on_overlay_save_selected", projection_reload_root)
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	editor.call("_on_binary_overlay_save_pressed")
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	editor.call("_on_binary_overlay_save_selected", draft_guard_binary_root)
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	editor.call("_on_binary_arc_export_pressed")
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	editor.call("_on_binary_arc_export_path_selected", draft_guard_arc_path)
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	editor.call("_on_overlay_detach_pressed")
	every_draft_callback_rejected = every_draft_callback_rejected and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("draft")
	_check(
		every_draft_callback_rejected
		and draft_guard_save_button.disabled
		and draft_guard_binary_button.disabled
		and draft_guard_arc_button.disabled
		and draft_guard_detach_button.disabled
		and editor.get("_pending_text_edits_by_entry")["TEST.MES"][0].text == "Pending projection"
		and message_edit.text == "Draft after staged value"
		and str(editor.get("_document").entry_sha256) == draft_guard_document_sha
		and editor.get("_overlay_messages") == draft_guard_overlay_messages
		and FileAccess.get_sha256(projection_reload_root + "/manifest.json") == draft_guard_manifest_sha
		and not FileAccess.file_exists(draft_guard_binary_root + "/manifest.json")
		and not FileAccess.file_exists(draft_guard_arc_path),
		"staged A plus draft B blocks every save, export, and detach callback without changing pending or output state"
	)
	message_edit.text = "Pending projection"
	editor.call("_on_message_text_changed", message_edit.text)
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		str(editor.get("_overlay_root")) == projection_root_before_block
		and editor.get("_overlay_messages")[0].text == "External projection B"
		and FileAccess.get_sha256(projection_reload_root + "/manifest.json") == projection_manifest_before_block
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("pending"),
		"MES Editor blocks Hot Reload while pending edits depend on the loaded overlay"
	)
	editor.call("_on_clear_overlay_pressed")
	_check(
		str(editor.get("_overlay_root")) == projection_root_before_block
		and editor.get("_overlay_messages")[0].text == "External projection B"
		and FileAccess.get_sha256(projection_reload_root + "/manifest.json") == projection_manifest_before_block
		and FileAccess.get_sha256(str(first_projection_reload.projection_path)) == first_projection_payload_sha
		and FileAccess.get_sha256(str(second_projection_reload.projection_path)) == projection_payload_before_block
		and str((editor.get_node("Margin/Layout/StatusLabel") as Label).text).contains("pending"),
		"MES Editor blocks Clear without changing the loaded manifest or projection payloads"
	)
	editor.call("_on_revert_text_pressed")
	editor.call("_on_clear_overlay_pressed")
	_check(
		str(editor.get("_overlay_root")).is_empty()
		and editor.get("_overlay_messages").is_empty()
		and str(editor.get("_document").source.resolved_source) == "original_arc"
		and message_tree.get_root().get_first_child().get_text(2) == "Localized hello"
		and FileAccess.get_sha256(projection_reload_root + "/manifest.json") == projection_manifest_before_block
		and hot_reload_overlay_button.disabled
		and clear_overlay_button.disabled,
		"clearing the projection overlay restores the original MES with cache presentation and leaves the package intact"
	)
	_check(
		not _tree_has_atomic_temporary(ProjectSettings.globalize_path(binary_reload_root))
		and not _tree_has_atomic_temporary(ProjectSettings.globalize_path(projection_reload_root)),
		"MES overlay reload fixtures leave no interrupted atomic temporary files"
	)
	overlay_source.close()
	var analysis: Dictionary = editor.get("_analysis")
	_check(analysis.ok and not analysis.complete and analysis.diagnostic_count == 1, "MES Editor retains a strict stop boundary without failing the entry")
	_check(analysis.message_count == 2, "MES Editor indexes only messages before the strict stop")
	_check(message_tree.get_root().get_child_count() == 3, "hash-bound cache supplements a message beyond the strict stop")
	var search_edit: LineEdit = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageSearchEdit")
	search_edit.text = "localized"
	editor.call("_rebuild_message_tree")
	_check(message_tree.get_root().get_child_count() == 1, "MES Editor searches hash-bound UTF-8 projections")
	_check(message_tree.get_root().get_first_child().get_text(2) == "Localized hello", "MES Editor displays the verified UTF-8 projection")
	search_edit.text = "cache only"
	editor.call("_rebuild_message_tree")
	_check(message_tree.get_root().get_child_count() == 1, "MES Editor searches cache records beyond a stopped decode prefix")
	search_edit.text = "hex:82a0"
	editor.call("_rebuild_message_tree")
	_check(message_tree.get_root().get_child_count() == 1, "MES Editor searches raw CP932 bytes by hex")
	_check(message_tree.get_root().get_first_child().get_text(2) == "あ", "MES Editor displays original CP932 bytes as Japanese text")
	search_edit.text = "あ"
	editor.call("_rebuild_message_tree")
	_check(message_tree.get_root().get_child_count() == 1, "MES Editor searches decoded Japanese CP932 text")
	search_edit.text = ""
	editor.call("_rebuild_message_tree")
	var first_message := message_tree.get_root().get_first_child()
	first_message.select(0)
	editor.call("_on_message_selected")
	var stage_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/MessageStageButton")
	var revert_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/MessageRevertButton")
	var save_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/OverlaySaveButton")
	_check(message_edit.editable and not stage_button.disabled, "strictly indexed message enables keyboard UTF-8 authoring")
	_check(message_edit.text == "Localized hello", "message authoring starts from the verified presentation projection")
	message_edit.text = "Overlay hello"
	editor.call("_on_stage_text_pressed")
	_check(editor.get("_pending_text_edits_by_entry")["TEST.MES"][0].text == "Overlay hello", "MES Editor stages an offset/hash-bound UTF-8 edit in memory")
	_check(not revert_button.disabled and not save_button.disabled, "pending edit enables Revert and Save overlay controls")
	_check(message_tree.get_root().get_first_child().get_text(2) == "Overlay hello", "pending edit has display priority over cache text")
	editor.call("_on_revert_text_pressed")
	_check(editor.get("_pending_text_edits_by_entry").is_empty() and message_edit.text == "Localized hello", "Revert removes only the pending edit and restores cache text")
	message_edit.text = "Overlay hello"
	editor.call("_on_message_text_submitted", message_edit.text)
	var other_entry := entry_item.get_next()
	other_entry.select(0)
	editor.call("_on_entry_selected")
	var other_message := message_tree.get_root().get_first_child()
	other_message.select(0)
	editor.call("_on_message_selected")
	message_edit.text = "Other overlay"
	editor.call("_on_message_text_submitted", message_edit.text)
	_check(editor.call("_pending_count_total") == 2 and not save_button.disabled, "pending edits survive entry selection and enable one batch save")
	var save_parser := CountingMesContainer.new()
	editor.set("_parser", save_parser)
	editor.call("_on_overlay_save_selected", overlay_root)
	_check(FileAccess.file_exists(overlay_root + "/manifest.json"), "MES Editor publishes an overlay manifest")
	_check(editor.get("_pending_text_edits_by_entry").is_empty(), "successful batch save clears every pending entry session")
	var overlay_manifest = JSON.parse_string(FileAccess.get_file_as_string(overlay_root + "/manifest.json"))
	_check(overlay_manifest is Dictionary and overlay_manifest.projections.size() == 2, "MES Editor publishes both pending entries in one overlay manifest")
	_check(
		save_parser.parse_count == 3
		and str(editor.get("_selected_entry_name")) == "OTHER.MES"
		and str(editor.get("_document").entry_sha256) == _sha256(mes)
		and editor.get("_overlay_messages")[0].text == "Other overlay",
		"MES Editor policy-preflights each pending entry and activates the selected entry only once"
	)
	entry_item.select(0)
	editor.call("_on_entry_selected")
	_check(editor.get("_overlay_messages")[0].text == "Overlay hello", "MES Editor loads another entry from the saved batch")
	_check(message_tree.get_root().get_first_child().get_text(2) == "Overlay hello", "saved overlay text has display priority over cache text")
	editor.set("_overlay_root", "")
	editor.set("_overlay_messages", {})
	editor.call("_on_overlay_load_selected", overlay_root)
	_check(editor.get("_overlay_messages")[0].text == "Overlay hello", "MES Editor loads a saved hash-bound overlay session")
	var detach_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/MessageAuthoring/OverlayDetachButton")
	_check(not detach_button.disabled, "loaded entry projection enables non-destructive detach")
	editor.call("_on_overlay_detach_pressed")
	_check(editor.get("_overlay_messages").is_empty() and detach_button.disabled, "MES Editor detaches the selected saved projection")
	_check(message_tree.get_root().get_first_child().get_text(2) == "Localized hello", "detaching overlay text restores the verified cache presentation")
	overlay_manifest = JSON.parse_string(FileAccess.get_file_as_string(overlay_root + "/manifest.json"))
	_check(overlay_manifest is Dictionary and overlay_manifest.projections.size() == 1, "MES Editor detach preserves the other entry projection")
	search_edit.text = "cache only"
	editor.call("_rebuild_message_tree")
	var cache_only_message := message_tree.get_root().get_first_child()
	cache_only_message.select(0)
	editor.call("_on_message_selected")
	_check(not message_edit.editable and stage_button.disabled, "cache-only post-stop messages remain read-only")
	search_edit.text = ""
	editor.call("_rebuild_message_tree")
	editor.call("_reset_navigation_history")
	editor.call("_select_address_for_offset", 0, false)
	var code_tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/References/CodeReferenceTree")
	var state_tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/References/StateReferenceTree")
	var resource_tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/References/ResourceReferenceTree")
	var reference_tabs: TabContainer = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/References")
	_check(code_tree.get_root().get_child_count() == 5, "MES Editor lists strict code references across address ranges")
	_check(state_tree.get_root().get_child_count() == 1, "MES Editor lists numeric state references")
	_check(resource_tree.get_root().get_child_count() == 1, "MES Editor lists strict bounded resource references")
	_check(
		resource_tree.get_root().get_first_child().get_text(2) == "BACK.AX"
		and resource_tree.get_root().get_first_child().get_text(3).contains(
			"data.arc / strict_indexed / data_arc_named_entry_load_confirmed"
		),
		"MES Editor labels the confirmed AX Data-loader boundary without claiming payload semantics"
	)
	_check(reference_tabs.get_tab_title(0) == "Code" and reference_tabs.get_tab_title(1) == "State" and reference_tabs.get_tab_title(2) == "Resources", "MES Editor gives each reference class a full-size subtab")
	var cfg_graph: GraphEdit = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgGraph")
	var graph_node_count := 0
	for child in cfg_graph.get_children():
		if child is GraphNode:
			graph_node_count += 1
	_check(graph_node_count == 7, "MES Editor expands confirmed flow and renders structural targets plus a decode stop")
	_check(cfg_graph.get_connection_list().size() == 5, "MES Editor renders confirmed and structural reference edges")
	var cfg_summary: Label = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgToolbar/CfgSummary")
	_check(cfg_summary.text.contains("1 reached range"), "MES Editor reports bounded cross-range expansion")
	var back_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgToolbar/CfgBackButton")
	var forward_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgToolbar/CfgForwardButton")
	_check(back_button.disabled and forward_button.disabled, "CFG navigation starts with one recorded range")
	var flow_filter: CheckButton = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgFilters/CfgShowConfirmed")
	var structural_filter: CheckButton = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgFilters/CfgShowStructural")
	var stop_filter: CheckButton = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/CFG/CfgFilters/CfgShowStops")
	structural_filter.button_pressed = false
	editor.call("_render_cfg_graph")
	_check(cfg_graph.get_connection_list().size() == 4 and _graph_node_count(cfg_graph) == 6, "CFG structural filter hides structural-only edges and nodes")
	structural_filter.button_pressed = true
	flow_filter.button_pressed = false
	editor.call("_render_cfg_graph")
	_check(cfg_graph.get_connection_list().size() == 1 and _graph_node_count(cfg_graph) == 3, "CFG flow filter can isolate structural references and stops")
	flow_filter.button_pressed = true
	stop_filter.button_pressed = false
	editor.call("_render_cfg_graph")
	_check(_graph_node_count(cfg_graph) == 6, "CFG stop filter hides exact decode-stop nodes")
	stop_filter.button_pressed = true
	editor.call("_render_cfg_graph")
	var focus_node: GraphNode = cfg_graph.get_node("instruction_00000007")
	editor.set("_cfg_selected_node_id", str(focus_node.name))
	editor.call("_on_cfg_focus_pressed")
	_check(focus_node.selected, "CFG Focus reselects the current visible node")
	structural_filter.button_pressed = false
	editor.call("_render_cfg_graph")
	var export_document: Dictionary = editor.call("_build_cfg_export_document")
	_check(export_document.schema == ContentCoreVersionScript.MES_REFERENCE_GRAPH_EXPORT_SCHEMA, "CFG JSON export uses its versioned schema")
	_check(export_document.graph.edge_count == 5 and export_document.visible.edges.size() == 4, "CFG JSON export retains the full graph and current visible projection")
	_check(not export_document.has("archive_path") and export_document.archive_sha256 == FileAccess.get_sha256(archive_path), "CFG JSON export binds hashes without a machine path")
	var export_json_path := TEST_ROOT + "/test_cfg.json"
	editor.call("_on_cfg_export_path_selected", export_json_path)
	var parsed_export = JSON.parse_string(FileAccess.get_file_as_string(export_json_path))
	_check(parsed_export is Dictionary and parsed_export.schema == ContentCoreVersionScript.MES_REFERENCE_GRAPH_EXPORT_SCHEMA, "CFG JSON export publishes a parseable new file")
	var published_sha := FileAccess.get_sha256(export_json_path)
	editor.call("_on_cfg_export_path_selected", export_json_path)
	_check(FileAccess.get_sha256(export_json_path) == published_sha, "CFG JSON export refuses to overwrite an existing output")
	var export_dot_path := TEST_ROOT + "/test_cfg.dot"
	editor.call("_on_cfg_export_path_selected", export_dot_path)
	var dot_text := FileAccess.get_file_as_string(export_dot_path)
	_check(dot_text.begins_with("digraph kakyu_mes_cfg") and not dot_text.contains("bootstrap_transfer_target"), "CFG DOT export reflects the current structural-edge filter")
	structural_filter.button_pressed = true
	editor.call("_render_cfg_graph")
	editor.call("_select_address_for_offset", 21, false)
	_check(not back_button.disabled and forward_button.disabled, "cross-range selection enables backward navigation")
	editor.call("_on_cfg_back_pressed")
	_check(_selected_range_offset(editor) == 0 and not forward_button.disabled, "CFG Back restores the prior address range")
	editor.call("_on_cfg_forward_pressed")
	_check(_selected_range_offset(editor) == 21 and not back_button.disabled, "CFG Forward restores the reached address range")
	entry_item.select(0)
	editor.call("_on_entry_selected")
	search_edit.text = ""
	editor.call("_rebuild_message_tree")
	var binary_message := message_tree.get_root().get_first_child()
	binary_message.select(0)
	editor.call("_on_message_selected")
	var binary_save_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryOverlaySaveButton")
	var binary_patch_label: Label = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryPatchLabel")
	var binary_arc_export_button: Button = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Messages/BinaryPatchBar/BinaryArcExportButton")
	message_edit.text = "WORLD"
	editor.call("_on_stage_text_pressed")
	_check(binary_save_button.disabled and binary_arc_export_button.disabled, "native-boundary mismatch permits UTF-8 overlay but disables binary outputs")
	var rejected_native_binary_root := TEST_ROOT + "/native-boundary-rejected-mod"
	editor.call("_on_binary_overlay_save_selected", rejected_native_binary_root)
	_check(not FileAccess.file_exists(rejected_native_binary_root + "/manifest.json"), "direct binary overlay validation rejects a native-boundary mismatch")
	var rejected_native_arc_path := TEST_ROOT + "/native-boundary-rejected.arc"
	editor.call("_on_binary_arc_export_path_selected", rejected_native_arc_path)
	_check(not FileAccess.file_exists(rejected_native_arc_path), "direct ARC export validation rejects a native-boundary mismatch")
	editor.call("_on_revert_text_pressed")
	binary_message = message_tree.get_root().get_first_child().get_next()
	binary_message.select(0)
	editor.call("_on_message_selected")
	message_edit.text = "ABC"
	editor.call("_on_message_text_changed", message_edit.text)
	_check(binary_patch_label.text.contains("3/2 bytes") and binary_patch_label.text.contains("exact length"), "MES Editor reports live CP932 byte-length mismatch before staging")
	editor.call("_on_stage_text_pressed")
	var overflow_policy: Dictionary = editor.call(
		"_assess_pending_output_policy", "original_cp932_candidate"
	)
	var overflow_utf8_policy: Dictionary = editor.call(
		"_assess_pending_output_policy", "remake_utf8_overlay"
	)
	_check(
		not overflow_policy.ready
		and _has_policy_blocker(overflow_policy, "byte_length_overflow")
		and overflow_utf8_policy.ready
		and overflow_utf8_policy.compatibility == "remake_only",
		"MES Editor separates CP932 overflow from a ready remake-only UTF-8 target"
	)
	_check(not binary_save_button.disabled, "pending edit enables the separate CP932 binary overlay action")
	var rejected_binary_root := TEST_ROOT + "/rejected_binary_mod"
	editor.call("_on_binary_overlay_save_selected", rejected_binary_root)
	_check(not FileAccess.file_exists(rejected_binary_root + "/manifest.json") and editor.call("_pending_count_total") == 1, "different-length CP932 batch fails before publishing and retains pending edits")
	message_edit.text = String.chr(0x3044)
	editor.call("_on_message_text_changed", message_edit.text)
	_check(
		binary_patch_label.text.contains("eligible 2/2 bytes")
		and binary_patch_label.text.contains("original_engine_unverified"),
		"MES Editor reports live equal-length CP932 eligibility and compatibility ceiling"
	)
	editor.call("_on_stage_text_pressed")
	var exact_policy: Dictionary = editor.call(
		"_assess_pending_output_policy", "original_cp932_candidate"
	)
	_check(
		exact_policy.ready and exact_policy.compatibility == "original_engine_unverified",
		"MES Editor preflights the staged CP932 candidate through the shared policy"
	)
	_check(not binary_arc_export_button.disabled, "valid pending edit enables a new CP932 ARC copy export")
	var binary_arc_path := TEST_ROOT + "/mes-cp932.arc"
	var changed_source_binary_arc_path := TEST_ROOT + "/changed-source-mes-cp932.arc"
	var export_changed_source := pristine_archive_bytes.duplicate()
	export_changed_source[export_changed_source.size() - 1] ^= 0x01
	_write_bytes(archive_path, export_changed_source)
	editor.call("_on_binary_arc_export_path_selected", changed_source_binary_arc_path)
	_check(
		not FileAccess.file_exists(changed_source_binary_arc_path)
		and (editor.get_node("Margin/Layout/StatusLabel") as Label).text.contains("changed after it was opened"),
		"MES ARC export rejects source bytes changed after the editor captured its open-time fingerprint"
	)
	_write_bytes(archive_path, pristine_archive_bytes)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "MES export source-mutation fixture restores the source ARC")
	editor.call("_on_binary_arc_export_path_selected", binary_arc_path)
	var binary_arc_reader := ArcReaderScript.new()
	_check(binary_arc_reader.open(binary_arc_path), "MES Editor CP932 ARC export reopens through the shared reader")
	if binary_arc_reader.is_open():
		_check(binary_arc_reader.read_entry("TEST.MES").slice(33, 35) == PackedByteArray([0x82, 0xA2]), "new ARC copy contains the native-boundary-matched CP932 replacement")
		_check(binary_arc_reader.read_entry("OTHER.MES") == mes, "new ARC copy preserves unchanged MES entries byte-identically")
		binary_arc_reader.close()
	var mes_provenance := ArcProvenanceScript.new().load_sidecar(binary_arc_path)
	_check(mes_provenance.get("ok", false) and mes_provenance.provenance.declared_compatibility == "original_engine_unverified", "MES Editor publishes portable unverified provenance for its CP932 ARC candidate")
	var binary_arc_sha := FileAccess.get_sha256(binary_arc_path)
	editor.call("_on_binary_arc_export_path_selected", binary_arc_path)
	_check(FileAccess.get_sha256(binary_arc_path) == binary_arc_sha, "MES Editor refuses to overwrite an existing CP932 ARC copy")
	_check(editor.call("_pending_count_total") == 1, "ARC copy export keeps the authored session available for overlay save")
	var binary_overlay_root := TEST_ROOT + "/binary_mod"
	editor.call("_on_binary_overlay_save_selected", binary_overlay_root)
	var binary_manifest = JSON.parse_string(FileAccess.get_file_as_string(binary_overlay_root + "/manifest.json"))
	_check(binary_manifest is Dictionary and binary_manifest.replacements.size() == 1 and binary_manifest.replacements[0].text_encoding == "cp932" and binary_manifest.replacements[0].compatibility == "original_engine_unverified", "MES Editor publishes the validated CP932 payload as an unverified binary candidate")
	_check(editor.get("_pending_text_edits_by_entry").is_empty() and binary_save_button.disabled, "successful CP932 save clears the pending session")
	_check(str(editor.get("_document").source.resolved_source) == "overlay", "MES Editor resolves binary MES content through overlay before original ARC")
	_check(message_tree.get_root().get_first_child().get_next().get_text(2) == String.chr(0x3044), "MES Editor displays CP932 text from the resolved binary replacement")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "MES Editor leaves its source ARC unchanged")

	editor.queue_free()
	await get_tree().process_frame
	await _test_startup_selection(archive_path, source_sha)
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _test_startup_selection(archive_path: String, source_sha: String) -> void:
	var selection_root := TEST_ROOT + "/selection_workspace"
	var content_root := TEST_ROOT
	var voice_archive_path := TEST_ROOT + "/voice.arc"
	SyntheticArc.write_arc(voice_archive_path, [{"name": "DUMMY.OGG", "data": PackedByteArray([1, 2, 3])}])
	var voice_sha := FileAccess.get_sha256(voice_archive_path)
	var archives := [
		{"archive": "mes.arc", "sha256": source_sha, "required": true},
		{"archive": "voice.arc", "sha256": voice_sha, "required": false},
	]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "mes-editor.selection.test",
		"project_version": "0.1.0", "display_name": "MES Editor Selection Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc", "voice.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(selection_root, content_root, project)
	_check(created.get("ok", false), "MES Editor selection fixture creates a named workspace")
	var snapshot := workspace.get_snapshot()
	workspace.close()

	var mes_reader := ArcReaderScript.new()
	mes_reader.open(archive_path)
	var entry_sha := mes_reader.get_entry_fingerprint("TEST.MES")
	mes_reader.close()
	var contract := ContentSelectionScript.new()
	var document := contract.build(
		snapshot,
		{
			"archive": "mes.arc", "entry": "TEST.MES", "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(document.get("ok", false), "MES Editor selection fixture builds a content selection for TEST.MES")
	var selection_path := TEST_ROOT + "/selection.json"
	_write_json(selection_path, document)

	var selection_editor: Control = MesEditorScene.instantiate()
	add_child(selection_editor)
	await get_tree().process_frame
	selection_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", content_root, "--workspace", selection_root, "--selection", selection_path,
	]))
	_check(
		str(selection_editor.get("_selected_entry_name")) == "TEST.MES"
		and str(selection_editor.get("_document").get("entry_sha256", "")) == entry_sha
		and (selection_editor.get_node("Margin/Layout/FilterEdit") as LineEdit).text.is_empty(),
		"MES Editor startup with --selection loads the named entry after resetting the filter"
	)

	var voice_reader := ArcReaderScript.new()
	voice_reader.open(voice_archive_path)
	var voice_entry_sha := voice_reader.get_entry_fingerprint("DUMMY.OGG")
	voice_reader.close()
	var wrong_archive_document := contract.build(
		snapshot,
		{
			"archive": "voice.arc", "entry": "DUMMY.OGG", "source_entry_sha256": voice_entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(wrong_archive_document.get("ok", false), "MES Editor selection fixture builds a voice.arc selection")
	var wrong_archive_path := TEST_ROOT + "/wrong-archive.selection.json"
	_write_json(wrong_archive_path, wrong_archive_document)
	var wrong_archive_editor: Control = MesEditorScene.instantiate()
	add_child(wrong_archive_editor)
	await get_tree().process_frame
	wrong_archive_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", content_root, "--workspace", selection_root, "--selection", wrong_archive_path,
	]))
	_check(
		str(wrong_archive_editor.get("_selected_entry_name")).is_empty()
		and (wrong_archive_editor.get_node("Margin/Layout/StatusLabel") as Label).text.begins_with("Selection rejected:"),
		"MES Editor rejects a selection naming another archive"
	)

	selection_editor.queue_free()
	wrong_archive_editor.queue_free()
	await get_tree().process_frame


func _controls_fit(editor: Control) -> bool:
	var margin: Control = editor.get_node("Margin")
	var layout: Control = editor.get_node("Margin/Layout")
	return Rect2(Vector2.ZERO, editor.size).encloses(margin.get_rect()) and margin.get_rect().size.y >= layout.get_combined_minimum_size().y


func _selected_range_offset(editor: Control) -> int:
	var tree: Tree = editor.get_node("Margin/Layout/MainSplit/Right/AnalysisTabs/Disassembly/AddressTree")
	var item := tree.get_selected()
	if item == null:
		return -1
	return int(item.get_metadata(0).offset)


func _graph_node_count(graph: GraphEdit) -> int:
	var count := 0
	for child in graph.get_children():
		if child is GraphNode:
			count += 1
	return count


func _synthetic_mes() -> PackedByteArray:
	var code := PackedByteArray()
	code.append(0x01)
	code.append_array("HELLO".to_ascii_buffer())
	code.append(0)
	code.append_array(PackedByteArray([0x0B, 0xF3, 0x34, 0x12, 0xFF]))
	SyntheticArc.append_u32(code, 21)
	code.append(0x0C)
	SyntheticArc.append_u32(code, 21)
	code.append_array(PackedByteArray([0x82, 0xA0, 0x00]))
	code.append_array(PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01]))
	code.append_array("back.ax".to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00]))
	code.append(0x0C)
	SyntheticArc.append_u32(code, 0)
	code.append_array(PackedByteArray([0x14, 0x01, 0xFF]))
	SyntheticArc.append_u32(code, 0)
	code.append_array(PackedByteArray([0x0B, 0xFF]))
	code.append(0x01)
	code.append_array("LATE".to_ascii_buffer())
	code.append(0)
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 2)
	SyntheticArc.append_u32(mes, 0)
	SyntheticArc.append_u32(mes, 21)
	mes.append_array(code)
	return mes


func _synthetic_invalid_cp932_mes() -> PackedByteArray:
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(PackedByteArray([0x8F, 0x01, 0x00, 0xFF]))
	return mes


func _run_workspace_project(source_archive_sha: String) -> Dictionary:
	var archives := [{
		"archive": "mes.arc", "sha256": source_archive_sha, "required": true,
	}]
	return {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA,
		"project_id": "mes-editor.test", "project_version": "0.1.0",
		"display_name": "MES Editor Test", "project_revision": 1,
		"content_core": {
			"minimum_version": ContentCoreVersionScript.CORE_VERSION,
			"maximum_exclusive": "1.0.0",
		},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["mes.arc"], "compatibility_objective": "mixed",
		"dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []},
		"overlay_manifest": "manifest.json",
	}


func _replace_ascii(source: PackedByteArray, offset: int, replacement: String) -> PackedByteArray:
	var updated := source.duplicate()
	var encoded := replacement.to_ascii_buffer()
	for index in range(encoded.size()):
		updated[offset + index] = encoded[index]
	return updated


func _create_text_cache(root: String, archive_path: String, entry_name: String, mes: PackedByteArray) -> void:
	var absolute_root := ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(absolute_root.path_join("entries"))
	var entry_relative := "entries/test.json"
	var entry_path := absolute_root.path_join(entry_relative)
	_write_json(entry_path, {
		"schema": ContentCoreVersionScript.MES_TEXT_ENTRY_SCHEMA,
		"entry": entry_name,
		"entry_sha256": _sha256(mes),
		"messages": [{
			"source_offset": 0,
			"text": "Localized hello",
			"raw_sha256": _sha256("HELLO".to_ascii_buffer()),
		}, {
			"source_offset": 58,
			"text": "Cache only message",
			"raw_sha256": _sha256("LATE".to_ascii_buffer()),
		}],
	})
	_write_json(absolute_root.path_join("manifest.json"), {
		"schema": ContentCoreVersionScript.MES_TEXT_CACHE_SCHEMA,
		"archive_sha256": FileAccess.get_sha256(archive_path),
		"entries": [{
			"entry": entry_name,
			"entry_sha256": _sha256(mes),
			"path": entry_relative,
			"file_sha256": FileAccess.get_sha256(entry_path),
		}],
	})


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()


func _write_bytes(path: String, value: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(value)
	file.close()


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for subdirectory in directory.get_directories():
		_remove_tree(path.path_join(subdirectory))
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)


func _tree_has_atomic_temporary(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return false
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	for filename in directory.get_files():
		if filename.contains(".tmp-"):
			return true
	for subdirectory in directory.get_directories():
		if _tree_has_atomic_temporary(path.path_join(subdirectory)):
			return true
	return false


func _has_policy_blocker(result: Dictionary, code: String) -> bool:
	for blocker in result.get("blockers", []):
		if str(blocker).ends_with(":" + code):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failed = true
		push_error("FAIL: " + label)
