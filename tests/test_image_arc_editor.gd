extends "res://tests/test_case.gd"

const MmoCodecScript := preload("res://content_core/mmo_codec.gd")
const DatPalCodecScript := preload("res://content_core/dat_pal_codec.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const A6LayoutScript := preload("res://content_core/a6_layout.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ImageEditorScene := preload("res://tools/content_suite/apps/image_arc_editor.tscn")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const ContentProjectScript := preload("res://content_core/content_project.gd")
const ContentWorkspaceScript := preload("res://content_core/content_workspace.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")
const TestHelpers := preload("res://tests/test_helpers.gd")

const TEST_ROOT := "user://image_arc_editor_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT + "/mmo.arc"
	var replacement_path := TEST_ROOT + "/replacement.png"
	var mismatch_path := TEST_ROOT + "/mismatch.png"
	var strip_path := TEST_ROOT + "/strip.png"
	var lossy_strip_path := TEST_ROOT + "/lossy-strip.png"
	var overlay_root := TEST_ROOT + "/my_mod"
	var loaded_overlay_root := TEST_ROOT + "/loaded_mod"
	var output_arc_path := TEST_ROOT + "/mmo-mod.arc"
	var changed_source_output_arc_path := TEST_ROOT + "/changed-source-mod.arc"
	var hidden_export_path := TEST_ROOT + "/hidden-selection.png"
	var original_image := _test_image(Color(1, 0, 0), Color(0, 1, 0))
	var replacement_image := _test_image(Color(0, 0, 1), Color(1, 1, 0))
	var original_encoded: Dictionary = MmoCodecScript.new().encode_image(original_image)
	var original_mmo: PackedByteArray = original_encoded.data
	var original_strip := _strip_image(Color(1, 0, 0, 1), Color(0, 1, 0, 1))
	var replacement_strip := _strip_image(Color(0, 0, 1, 1), Color(1, 1, 0, 1))
	var original_pair: Dictionary = DatPalCodecScript.new().encode_image(original_strip)
	var original_metadata := PackedByteArray([1, 2, 3, 4])
	var overlay_metadata := PackedByteArray([5, 6, 7, 8])
	var a6_data := PackedByteArray()
	a6_data.resize(12)
	for field_index in range(5):
		a6_data.encode_u16(field_index * 2, field_index + 1)
	a6_data.encode_u16(10, 0xFFFF)
	var ax_data := _ax_binding_fixture()
	SyntheticArc.write_arc(archive_path, [
		{"name": "TEST.MMO", "data": original_mmo},
		{"name": "CHARA.DAT", "data": original_pair.dat_data},
		{"name": "CHARA.PAL", "data": original_pair.pal_data},
		{"name": "MENU1.A6", "data": a6_data},
		{"name": "A01.AX", "data": ax_data},
		{"name": "META.BIN", "data": original_metadata},
	])
	var initial_overlay_a6 := a6_data.duplicate()
	initial_overlay_a6.encode_u16(6, 7)
	var initial_overlay_mmo := MmoCodecScript.new().encode_image(
		replacement_image,
		original_mmo.slice(0, MmoCodecScript.new().HEADER_SIZE)
	)
	_check(initial_overlay_mmo.ok, "overlay read-layer MMO fixture encodes with the original target header")
	var initial_overlay_pair := DatPalCodecScript.new().encode_image(replacement_strip)
	_check(initial_overlay_pair.ok, "overlay read-layer DAT/PAL fixture encodes")
	var overlay_reader := ArcReaderScript.new()
	_check(overlay_reader.open(archive_path), "overlay read-layer fixture opens its source ARC")
	var initial_overlay := OverlayPackageScript.new().stage_replacements(
		loaded_overlay_root,
		overlay_reader,
		"mmo.arc",
		{
			"MENU1.A6": initial_overlay_a6,
			"TEST.MMO": initial_overlay_mmo.data,
			"CHARA.DAT": initial_overlay_pair.dat_data,
			"CHARA.PAL": initial_overlay_pair.pal_data,
			"A01.AX": ax_data,
			"META.BIN": overlay_metadata,
		},
		"remake_only",
		"not_applicable"
	)
	_check(initial_overlay.ok, "overlay read-layer fixture publishes hash-bound image/layout and non-image replacements")
	overlay_reader.close()
	_check(replacement_image.save_png(replacement_path) == OK, "replacement PNG fixture saves")
	_check(Image.create(1, 1, false, Image.FORMAT_RGB8).save_png(mismatch_path) == OK, "mismatch PNG fixture saves")
	_check(replacement_strip.save_png(strip_path) == OK, "DAT/PAL replacement PNG fixture saves")
	var lossy_strip := Image.create(640, 32, false, Image.FORMAT_RGBA8)
	for index in range(300):
		lossy_strip.set_pixel(index, 0, Color8(index & 0xFF, (index * 17) & 0xFF, (index * 37) & 0xFF, 255))
	_check(lossy_strip.save_png(lossy_strip_path) == OK, "lossy DAT/PAL comparison fixture saves")
	var pristine_archive_bytes := FileAccess.get_file_as_bytes(archive_path)
	var source_sha := FileAccess.get_sha256(archive_path)

	var editor: Control = ImageEditorScene.instantiate()
	editor.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("path_history.cfg")))
	add_child(editor)
	await get_tree().process_frame
	editor.call("_open_archive", archive_path)
	_check((editor.get("_path_history") as ContentToolPathHistory).get_last_source_directory() == absolute_root.simplify_path(), "image editor remembers its successfully opened ARC directory")
	_check((editor.get_node("OpenDialog") as FileDialog).current_dir.simplify_path() == absolute_root.simplify_path(), "image editor reopens its ARC chooser at the remembered directory")
	_check(get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "image editor uses native desktop pixels")
	_check(editor.size == Vector2(get_window().size), "image editor fills the desktop client area")
	_check(_controls_fit(editor), "image editor controls fit the desktop client area")
	var original_window_size := get_window().size
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(editor.size == Vector2(1024, 640) and _controls_fit(editor), "image editor remains usable at the shared minimum desktop size")
	get_window().size = original_window_size
	await get_tree().process_frame
	editor.set("_selected_name", "MENU1.A6")
	editor.call("_decode_selected")
	var details: RichTextLabel = editor.get_node("Margin/Layout/Split/Right/Details")
	var status: Label = editor.get_node("Margin/Layout/StatusLabel")
	_check(
		details.text.contains("Record count: 1")
		and details.text.contains("ID, left, top, right, bottom")
		and details.text.contains("Edges: inclusive")
		and details.text.contains("(2, 3) .. (4, 5)"),
		"Image Editor exposes the EXE-confirmed A6 input rectangle without presenting it as pixels"
	)
	_check(editor.get("_decoded_image") == null, "A6 inspection does not pretend the table is a decoded image")
	var a6_editor: VBoxContainer = editor.get_node("Margin/Layout/Split/Right/A6Editor")
	var a6_record_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/A6Editor/RecordRow/A6RecordSelect")
	var a6_id: SpinBox = editor.get_node("Margin/Layout/Split/Right/A6Editor/RecordRow/A6Id")
	var a6_left: SpinBox = editor.get_node("Margin/Layout/Split/Right/A6Editor/CoordinateRow/A6Left")
	var a6_top: SpinBox = editor.get_node("Margin/Layout/Split/Right/A6Editor/CoordinateRow/A6Top")
	var a6_right: SpinBox = editor.get_node("Margin/Layout/Split/Right/A6Editor/CoordinateRow/A6Right")
	var a6_bottom: SpinBox = editor.get_node("Margin/Layout/Split/Right/A6Editor/CoordinateRow/A6Bottom")
	var a6_add: Button = editor.get_node("Margin/Layout/Split/Right/A6Editor/Operations/A6Add")
	var a6_duplicate: Button = editor.get_node("Margin/Layout/Split/Right/A6Editor/Operations/A6Duplicate")
	var a6_remove: Button = editor.get_node("Margin/Layout/Split/Right/A6Editor/Operations/A6Remove")
	var a6_move_up: Button = editor.get_node("Margin/Layout/Split/Right/A6Editor/Operations/A6MoveUp")
	var a6_move_down: Button = editor.get_node("Margin/Layout/Split/Right/A6Editor/Operations/A6MoveDown")
	var a6_diagnostics: Label = editor.get_node("Margin/Layout/Split/Right/A6Editor/Operations/A6Diagnostics")
	_check(
		a6_editor.visible
		and a6_record_select.item_count == 1
		and int(a6_left.value) == 2
		and int(a6_right.value) == 4
		and not a6_add.disabled
		and not a6_duplicate.disabled
		and not a6_remove.disabled
		and a6_move_up.disabled
		and a6_move_down.disabled,
		"Image Editor exposes existing A6 records as bounded editable fields"
	)
	var a6_overlay: ContentToolA6RegionOverlay = editor.get("_a6_region_overlay")
	_check(
		a6_overlay.size == Vector2(640, 400)
		and a6_overlay.get_region_count() == 1
		and a6_overlay.get_region_rect(0) == Rect2(Vector2(2, 3), Vector2(3, 3)),
		"A6 game frame draws inclusive stored rectangles in logical coordinates"
	)
	editor.call("_on_game_preview_pointer_pressed", Vector2(4, 5))
	_check(
		a6_overlay.get_selected_index() == 0
		and status.text.contains("first matching A6 record #0"),
		"A6 game-frame click selects the native first match on inclusive right/bottom edges"
	)
	editor.call("_on_game_preview_pointer_pressed", Vector2(0, 0))
	_check(status.text.contains("No A6 input region"), "A6 game-frame click reports an unmatched logical coordinate")
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(editor.size == Vector2(1024, 640) and _controls_fit(editor), "A6 editing controls fit the shared minimum desktop size")
	get_window().size = original_window_size
	await get_tree().process_frame
	editor.call("_on_load_overlay_directory_selected", loaded_overlay_root)
	_check(
		int(a6_right.value) == 7
		and details.text.contains("Resolved source: overlay")
		and str(editor.get("_overlay_root")).simplify_path() == ProjectSettings.globalize_path(loaded_overlay_root).simplify_path(),
		"Image Editor loads an existing overlay as the active A6 read layer"
	)
	var a6_tree_item: TreeItem = (editor.get("_entry_items") as Dictionary)["MENU1.A6"]
	_check(a6_tree_item.get_text(2).contains("Overlay"), "Image Editor marks entries resolved from the loaded overlay")
	editor.set("_selected_name", "TEST.MMO")
	editor.call("_decode_selected")
	_check(
		(editor.get("_decoded_image") as Image).get_data() == replacement_image.get_data()
		and details.text.contains("Resolved source: overlay")
		and details.text.contains("MMO header profile: standard_mirrored_dimensions")
		and details.text.contains("Header secondary dimensions: 2 × 2"),
		"Image Editor decodes MMO pixels and exposes its header profile through the loaded overlay"
	)
	var filter_edit: LineEdit = editor.get_node("Margin/Layout/FilterEdit")
	var import_button: Button = editor.get_node("Margin/Layout/SessionToolbar/Import")
	var remove_button: Button = editor.get_node("Margin/Layout/SessionToolbar/Remove")
	var export_button: Button = editor.get_node("Margin/Layout/Toolbar/Export")
	filter_edit.text = "test"
	editor.call("_on_filter_changed", filter_edit.text)
	await get_tree().process_frame
	var filtered_selected: TreeItem = (editor.get_node("Margin/Layout/Split/EntryTree") as Tree).get_selected()
	_check(
		str(editor.get("_selected_name")) == "TEST.MMO"
		and filtered_selected != null
		and str(filtered_selected.get_metadata(0)) == "TEST.MMO"
		and editor.get("_decoded_image") != null,
		"Image Editor restores a selected row only while it remains visible through filtering"
	)
	filter_edit.text = "chara"
	editor.call("_on_filter_changed", filter_edit.text)
	await get_tree().process_frame
	_check(
		str(editor.get("_selected_name")).is_empty()
		and (editor.get_node("Margin/Layout/Split/EntryTree") as Tree).get_selected() == null
		and editor.get("_decoded_image") == null,
		"Image Editor clears a selected asset and its preview when the filter hides it"
	)
	_check(import_button.disabled and remove_button.disabled and export_button.disabled, "hidden image selection disables import, remove, and PNG export actions")
	var hidden_session: Dictionary = (editor.get("_session") as Dictionary).duplicate(true)
	editor.call("_on_replacement_path_selected", replacement_path)
	editor.call("_on_export_path_selected", hidden_export_path)
	_check(
		(editor.get("_session") as Dictionary) == hidden_session
		and not FileAccess.file_exists(hidden_export_path),
		"stale replacement and export callbacks fail closed after a selection is filtered out"
	)
	filter_edit.text = ""
	editor.call("_on_filter_changed", filter_edit.text)
	await get_tree().process_frame
	_check(str(editor.get("_selected_name")).is_empty(), "clearing the filter does not silently restore a previously hidden write target")
	var restored_test_item: TreeItem = (editor.get("_entry_items") as Dictionary)["TEST.MMO"]
	restored_test_item.select(0)
	if str(editor.get("_selected_name")) != "TEST.MMO":
		editor.call("_on_entry_selected")
	await get_tree().process_frame
	_check(
		str(editor.get("_selected_name")) == "TEST.MMO"
		and editor.get("_decoded_image") != null
		and not import_button.disabled
		and not export_button.disabled
		and remove_button.disabled,
		"selecting the visible image again restores only its valid preview actions"
	)
	var previous_resolver: Object = editor.get("_resolver")
	var previous_root := str(editor.get("_overlay_root"))
	var previous_targets: Dictionary = (editor.get("_overlay_targets") as Dictionary).duplicate(true)
	var previous_snapshot: Dictionary = previous_resolver.call("get_overlay_snapshot")
	var active_bindings: Dictionary = previous_resolver.call("validate_overlay_archive_bindings", "mmo.arc")
	var previous_effective: Dictionary = editor.call("_read_effective_entry", "TEST.MMO")
	var previous_details := details.text
	var previous_texture: Texture2D = editor.get_node("Margin/Layout/Split/Right/PreviewTabs/AssetView/Preview").texture
	var previous_decoded_data := (editor.get("_decoded_image") as Image).get_data()
	var previous_session: Dictionary = (editor.get("_session") as Dictionary).duplicate(true)
	var previous_source_label := str((editor.get("_entry_items") as Dictionary)["TEST.MMO"].get_text(2))
	var snapshot_records: Dictionary = {}
	for untyped_record in previous_snapshot.manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == "MMO.ARC":
			snapshot_records[str(record.target_entry).to_upper()] = record
	_check(
		str(previous_snapshot.root) == previous_root
		and previous_snapshot.manifest.replacements.size() == 6
		and previous_targets.size() == 6
		and active_bindings.ok
		and active_bindings.records.size() == 6
		and active_bindings.descriptors.size() == 6
		and str(active_bindings.archive_sha256) == source_sha
		and previous_targets.has("META.BIN")
		and active_bindings.descriptors.has("META.BIN")
		and snapshot_records.has("TEST.MMO")
		and snapshot_records.has("META.BIN")
		and str(snapshot_records["TEST.MMO"].replacement_sha256) == str(previous_targets["TEST.MMO"].replacement_sha256)
		and str(snapshot_records["META.BIN"].replacement_sha256) == str(previous_targets["META.BIN"].replacement_sha256),
		"Image Editor derives image and non-image targets from an all-record batch-bound resolver snapshot"
	)
	_check(
		previous_resolver.call("resolve", "mmo.arc", "TEST.MMO") == active_bindings.descriptors["TEST.MMO"],
		"Image Editor normal resolve matches the independently batch-validated image descriptor"
	)
	var manifest_path := ProjectSettings.globalize_path(loaded_overlay_root).simplify_path().path_join("manifest.json")
	var valid_manifest_text := FileAccess.get_file_as_string(manifest_path)
	var wrong_base_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	for untyped_record in wrong_base_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_entry).to_upper() == "META.BIN":
			record.base_archive_sha256 = "0".repeat(64)
	_write_text(manifest_path, JSON.stringify(wrong_base_manifest, "\t") + "\n")
	_check(OverlayPackageScript.new().load_manifest(loaded_overlay_root).ok, "wrong-base Image Hot Reload fixture remains structurally valid")
	editor.call("_on_hot_reload_overlay_pressed")
	var rejected_snapshot: Dictionary = previous_resolver.call("get_overlay_snapshot")
	var rejected_effective: Dictionary = editor.call("_read_effective_entry", "TEST.MMO")
	_check(
		status.text.contains("Overlay Hot Reload failed")
		and status.text.contains("base ARC hash does not match"),
		"Image Editor rejects a wrong-base non-image record in the current archive"
	)
	_check(
		editor.get("_resolver") == previous_resolver
		and str(editor.get("_overlay_root")) == previous_root
		and editor.get("_overlay_targets") == previous_targets
		and rejected_snapshot == previous_snapshot,
		"failed Image Hot Reload preserves the previous resolver, root, targets, and snapshot"
	)
	_check(
		rejected_effective.ok
		and rejected_effective.source == "overlay"
		and rejected_effective.data == previous_effective.data
		and details.text == previous_details
		and editor.get_node("Margin/Layout/Split/Right/PreviewTabs/AssetView/Preview").texture == previous_texture
		and (editor.get("_decoded_image") as Image).get_data() == previous_decoded_data
		and str((editor.get("_entry_items") as Dictionary)["TEST.MMO"].get_text(2)) == previous_source_label
		and editor.get("_session") == previous_session,
		"failed Image Hot Reload preserves effective pixels, details, textures, source label, and pending state"
	)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "rejected Image Hot Reload leaves the source ARC unchanged")

	var missing_target_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	for untyped_record in missing_target_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_entry).to_upper() == "META.BIN":
			record.target_entry = "MISSING.BIN"
	_write_text(manifest_path, JSON.stringify(missing_target_manifest, "\t") + "\n")
	_check(OverlayPackageScript.new().load_manifest(loaded_overlay_root).ok, "missing-target Image Hot Reload fixture remains structurally valid")
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		status.text.contains("Overlay Hot Reload failed")
		and status.text.contains("target entry is missing")
		and editor.get("_resolver") == previous_resolver
		and editor.get("_overlay_targets") == previous_targets
		and previous_resolver.call("get_overlay_snapshot") == previous_snapshot
		and editor.call("_read_effective_entry", "TEST.MMO").data == previous_effective.data
		and details.text == previous_details
		and editor.get_node("Margin/Layout/Split/Right/PreviewTabs/AssetView/Preview").texture == previous_texture
		and editor.get("_session") == previous_session,
		"missing-target Image Hot Reload is rejected without disturbing the active read or preview state"
	)

	var changed_archive_bytes := pristine_archive_bytes.duplicate()
	var editor_reader: KakyuArcReader = editor.get("_reader")
	var metadata_offset := int(editor_reader.get_entry("META.BIN").offset)
	changed_archive_bytes[metadata_offset] = changed_archive_bytes[metadata_offset] ^ 0x01
	_write_bytes(archive_path, changed_archive_bytes)
	var changed_archive_sha := FileAccess.get_sha256(archive_path)
	var changed_metadata := original_metadata.duplicate()
	changed_metadata[0] = changed_metadata[0] ^ 0x01
	var rebound_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	for untyped_record in rebound_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_archive).to_upper() == "MMO.ARC":
			record.base_archive_sha256 = changed_archive_sha
		if str(record.target_entry).to_upper() == "META.BIN":
			record.original_entry_sha256 = OverlayPackageScript.sha256_bytes(changed_metadata)
	_write_text(manifest_path, JSON.stringify(rebound_manifest, "\t") + "\n")
	_check(OverlayPackageScript.new().load_manifest(loaded_overlay_root).ok, "changed-source Image Hot Reload fixture remains structurally valid and rebound")
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		status.text.contains("Overlay Hot Reload failed")
		and status.text.contains("open image ARC changed"),
		"Image Editor rejects a candidate rebound to source bytes changed after open"
	)
	_check(
		editor.get("_resolver") == previous_resolver
		and str(editor.get("_overlay_root")) == previous_root
		and editor.get("_overlay_targets") == previous_targets
		and previous_resolver.call("get_overlay_snapshot") == previous_snapshot
		and details.text == previous_details
		and editor.get_node("Margin/Layout/Split/Right/PreviewTabs/AssetView/Preview").texture == previous_texture
		and (editor.get("_decoded_image") as Image).get_data() == previous_decoded_data
		and str((editor.get("_entry_items") as Dictionary)["TEST.MMO"].get_text(2)) == previous_source_label
		and editor.get("_session") == previous_session
		and str(editor.get("_archive_sha256")) == source_sha,
		"changed-source Image rejection preserves resolver, overlay metadata, details, pixels, texture, source label, pending state, and pinned SHA"
	)
	_write_bytes(archive_path, pristine_archive_bytes)
	_write_text(manifest_path, valid_manifest_text)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "changed-source Image fixture restores its byte-identical ARC")
	_check(editor_reader.open(archive_path), "Image Editor reader reopens the restored ARC")
	_check(previous_resolver.call("register_original_archive", "mmo.arc", archive_path), "Image active resolver reopens the restored ARC")
	var restored_effective: Dictionary = editor.call("_read_effective_entry", "TEST.MMO")
	_check(restored_effective.ok and restored_effective.data == previous_effective.data, "Image overlay resolution resumes after restoring and reopening the source ARC")

	var partial_pair_manifest: Dictionary = JSON.parse_string(valid_manifest_text)
	var partial_records: Array = []
	for untyped_record in partial_pair_manifest.replacements:
		var record: Dictionary = untyped_record
		if str(record.target_entry).to_upper() != "CHARA.DAT":
			partial_records.append(record)
	partial_pair_manifest.replacements = partial_records
	_write_text(manifest_path, JSON.stringify(partial_pair_manifest, "\t") + "\n")
	editor.set("_selected_name", "CHARA.DAT")
	editor.call("_on_hot_reload_overlay_pressed")
	_check(
		status.text.contains("Hot Reloaded overlay")
		and details.text.contains("Resolved source: DAT original_arc + PAL overlay")
		and str((editor.get("_entry_items") as Dictionary)["CHARA.DAT"].get_text(2)).contains("Overlay"),
		"Image Editor activates a valid PAL-only overlay and preserves the logical DAT/PAL row badge"
	)
	_write_text(manifest_path, valid_manifest_text)
	editor.call("_on_hot_reload_overlay_pressed")
	_check(details.text.contains("Resolved source: DAT overlay + PAL overlay"), "Image Editor restores the full DAT/PAL overlay after partial-pair validation")
	editor.set("_selected_name", "MENU1.A6")
	editor.call("_decode_selected")
	editor.set("_selected_name", "CHARA.DAT")
	editor.call("_decode_selected")
	_check(
		_visible_strip_equal(editor.get("_decoded_image"), replacement_strip)
		and details.text.contains("Resolved source: DAT overlay + PAL overlay"),
		"Image Editor resolves both halves of a loaded DAT/PAL overlay pair"
	)
	var palette_editor: HFlowContainer = editor.get_node("Margin/Layout/Split/Right/PaletteEditor")
	var palette_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/PaletteEditor/PaletteEntrySelect")
	var palette_color: ColorPickerButton = editor.get_node("Margin/Layout/Split/Right/PaletteEditor/PaletteColor")
	var palette_stage: Button = editor.get_node("Margin/Layout/Split/Right/PaletteEditor/StagePalette")
	_check(
		palette_editor.visible
		and palette_select.item_count == 256
		and str(editor.get("_palette_document").schema) == ContentCoreVersionScript.DAT_PAL_PALETTE_SCHEMA,
		"Image Editor exposes the full effective DAT/PAL palette through the versioned core contract"
	)
	palette_select.select(0)
	editor.call("_on_palette_entry_selected", 0)
	_check(palette_stage.disabled and (editor.get_node("Margin/Layout/Split/Right/PaletteEditor/PaletteSummary") as Label).text.contains("reserved for alpha"), "Image Editor disables editing the reserved transparent index zero")
	var used_palette_index := -1
	var used_palette_count := 0
	for untyped_entry in (editor.get("_palette_document") as Dictionary).entries:
		var palette_entry: Dictionary = untyped_entry
		if int(palette_entry.index) > 0 and int(palette_entry.use_count) > 0:
			used_palette_index = int(palette_entry.index)
			used_palette_count = int(palette_entry.use_count)
			break
	_check(used_palette_index > 0, "palette edit fixture locates a referenced non-reserved entry")
	palette_select.select(used_palette_index)
	editor.call("_on_palette_entry_selected", used_palette_index)
	palette_color.color = Color8(123, 45, 67, 255)
	_check(not palette_stage.disabled, "Image Editor enables staging a non-reserved palette entry")
	editor.call("_on_stage_palette_pressed")
	var palette_session: Dictionary = editor.get("_session")
	var palette_name := "CHARA.PAL"
	var staged_palette: Dictionary = editor.call("_load_descriptor", palette_name, palette_session["CHARA.DAT"].files[palette_name]) if palette_session.has("CHARA.DAT") else {"ok": false}
	_check(
		palette_session.has("CHARA.DAT")
		and palette_session["CHARA.DAT"].authoring_origin == "palette_edit"
		and int(palette_session["CHARA.DAT"].palette_edit.index) == used_palette_index
		and int(palette_session["CHARA.DAT"].palette_edit.use_count) == used_palette_count
		and staged_palette.ok
		and staged_palette.data[used_palette_index * 3] == 67
		and staged_palette.data[used_palette_index * 3 + 1] == 45
		and staged_palette.data[used_palette_index * 3 + 2] == 123
		and details.text.contains("Palette edit: #%03d" % used_palette_index),
		"Image Editor stages and reopens one BGR palette mutation as a paired DAT/PAL session"
	)
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(editor.size == Vector2(1024, 640) and _controls_fit(editor), "palette editing controls fit the shared minimum desktop size")
	get_window().size = original_window_size
	await get_tree().process_frame
	editor.call("_on_remove_replacement_pressed")
	_check(
		not (editor.get("_session") as Dictionary).has("CHARA.DAT")
		and _visible_strip_equal(editor.get("_decoded_image"), replacement_strip)
		and FileAccess.get_sha256(archive_path) == source_sha,
		"removing a palette edit restores the effective overlay pair without changing the source ARC"
	)
	editor.set("_selected_name", "A01.AX")
	editor.call("_decode_selected")
	_check(details.text.contains("Resolved source: overlay"), "Image Editor inspects AX structure through the loaded overlay layer")
	_check(details.text.contains("Writer round trip: byte-identical"), "Image Editor confirms the AX writer's byte-identical round trip")
	editor.call("_on_import_pressed")
	_check(
		status.text.contains("animation timeline (ME-02)") and status.text.contains("PNG import does not apply"),
		"Image Editor directs AX editing to the animation timeline instead of PNG import"
	)
	editor.set("_selected_name", "MENU1.A6")
	editor.call("_decode_selected")
	var reloaded_overlay_a6 := initial_overlay_a6.duplicate()
	reloaded_overlay_a6.encode_u16(6, 8)
	_check(overlay_reader.open(archive_path), "overlay Hot Reload fixture reopens its source ARC")
	var reloaded_overlay := OverlayPackageScript.new().stage_replacement(
		loaded_overlay_root,
		overlay_reader,
		"mmo.arc",
		"MENU1.A6",
		reloaded_overlay_a6,
		"original_engine_compatible",
		"not_applicable"
	)
	_check(reloaded_overlay.ok, "overlay Hot Reload fixture atomically updates the A6 replacement")
	overlay_reader.close()
	editor.call("_on_hot_reload_overlay_pressed")
	_check(int(a6_right.value) == 8 and status.text.contains("Hot Reloaded overlay"), "Image Editor Hot Reload reopens changed overlay bytes")
	editor.call("_on_import_pressed")
	_check(status.text.contains("do not accept PNG") and status.text.contains("A6 panel"), "Image Editor directs A6 editing away from the PNG replacement path")
	a6_left.value = 10
	editor.call("_on_stage_a6_record_pressed")
	_check(status.text.contains("inverted") and editor.get("_session").is_empty(), "Image Editor rejects an inverted A6 rectangle before staging")
	a6_left.value = 2
	a6_right.value = 9
	editor.call("_on_stage_a6_record_pressed")
	var a6_session: Dictionary = editor.get("_session")
	_check(a6_session.size() == 1 and a6_session.has("MENU1.A6"), "verified A6 rectangle edit enters the shared image session")
	editor.call("_on_clear_overlay_pressed")
	_check(
		status.text.contains("before changing the overlay read layer")
		and not str(editor.get("_overlay_root")).is_empty(),
		"Image Editor blocks overlay changes while a pending edit depends on that read layer"
	)
	_check(FileAccess.file_exists(a6_session["MENU1.A6"].path), "encoded A6 payload is staged in the user cache")
	var staged_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		staged_a6.ok
		and int(staged_a6.records[0].left) == 2
		and int(staged_a6.records[0].right) == 9,
		"staged A6 payload reopens with the edited inclusive rectangle"
	)
	_check(a6_overlay.get_region_rect(0) == Rect2(Vector2(2, 3), Vector2(8, 3)), "A6 game frame refreshes from the reopened staged table")
	var a6_path := str(a6_session["MENU1.A6"].path)
	editor.call("_on_add_a6_record_pressed")
	a6_session = editor.get("_session")
	var added_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		added_a6.ok
		and int(added_a6.record_count) == 2
		and int(a6_record_select.selected) == 1
		and int(added_a6.records[1].id) == 0
		and int(added_a6.records[1].left) == 0
		and int(added_a6.records[1].bottom) == 0
		and str(a6_session["MENU1.A6"].edit_operation) == "insert"
		and not FileAccess.file_exists(a6_path)
		and not a6_move_up.disabled
		and a6_move_down.disabled,
		"A6 Add after publishes a reopened row with the smallest unused ID and removes the superseded cache file"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_duplicate_a6_record_pressed")
	a6_session = editor.get("_session")
	var duplicated_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		duplicated_a6.ok
		and int(duplicated_a6.record_count) == 3
		and int(a6_record_select.selected) == 2
		and bool(duplicated_a6.records[2].fully_unreachable_by_first_match)
		and int(duplicated_a6.unreachable_record_count) == 1
		and a6_record_select.get_item_text(2).contains("unreachable")
		and a6_diagnostics.text.contains("1 unreachable")
		and str(a6_session["MENU1.A6"].edit_operation) == "duplicate"
		and not FileAccess.file_exists(a6_path),
		"A6 Duplicate retains order and reports a fully shadowed later row under native first-match semantics"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_move_a6_record_up_pressed")
	a6_session = editor.get("_session")
	var moved_up_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		moved_up_a6.ok
		and int(a6_record_select.selected) == 1
		and bool(moved_up_a6.records[2].fully_unreachable_by_first_match)
		and str(a6_session["MENU1.A6"].edit_operation) == "move"
		and not a6_move_up.disabled
		and not a6_move_down.disabled
		and not FileAccess.file_exists(a6_path),
		"A6 Move up reopens the ordered table and keeps first-match reachability diagnostics synchronized"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_move_a6_record_down_pressed")
	a6_session = editor.get("_session")
	_check(
		int(a6_record_select.selected) == 2
		and str(a6_session["MENU1.A6"].edit_operation) == "move"
		and not a6_move_up.disabled
		and a6_move_down.disabled
		and not FileAccess.file_exists(a6_path),
		"A6 Move down restores the selected row at the end and disables only the impossible direction"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_remove_a6_record_pressed")
	a6_session = editor.get("_session")
	var once_removed_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		once_removed_a6.ok
		and int(once_removed_a6.record_count) == 2
		and int(a6_record_select.selected) == 1
		and int(once_removed_a6.unreachable_record_count) == 0
		and not FileAccess.file_exists(a6_path),
		"A6 Remove drops the duplicate and recomputes the first-match diagnostics"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_remove_a6_record_pressed")
	a6_session = editor.get("_session")
	var restored_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		restored_a6.ok
		and int(restored_a6.record_count) == 1
		and int(restored_a6.records[0].left) == 2
		and int(restored_a6.records[0].right) == 9
		and int(a6_record_select.selected) == 0
		and a6_move_up.disabled
		and a6_move_down.disabled
		and not FileAccess.file_exists(a6_path)
		and FileAccess.get_sha256(archive_path) == source_sha,
		"A6 ordered-table operations can return to the verified single-row edit without changing the source ARC"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_remove_a6_record_pressed")
	a6_session = editor.get("_session")
	var empty_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		empty_a6.ok
		and int(empty_a6.record_count) == 0
		and a6_record_select.disabled
		and not a6_add.disabled
		and a6_duplicate.disabled
		and a6_remove.disabled
		and a6_move_up.disabled
		and a6_move_down.disabled
		and a6_diagnostics.text.contains("0 records")
		and not FileAccess.file_exists(a6_path),
		"A6 Remove can publish a valid terminal-only table while Add remains available"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.call("_on_add_a6_record_pressed")
	a6_id.value = 1
	a6_left.value = 2
	a6_top.value = 3
	a6_right.value = 9
	a6_bottom.value = 5
	editor.call("_on_stage_a6_record_pressed")
	a6_session = editor.get("_session")
	var rebuilt_single_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(a6_session["MENU1.A6"].path))
	_check(
		rebuilt_single_a6.ok
		and int(rebuilt_single_a6.record_count) == 1
		and int(rebuilt_single_a6.records[0].id) == 1
		and int(rebuilt_single_a6.records[0].left) == 2
		and int(rebuilt_single_a6.records[0].top) == 3
		and int(rebuilt_single_a6.records[0].right) == 9
		and int(rebuilt_single_a6.records[0].bottom) == 5
		and str(a6_session["MENU1.A6"].edit_operation) == "field_edit"
		and not FileAccess.file_exists(a6_path),
		"A6 Add can recreate the first row of an empty table and the field editor restores the verified session"
	)
	a6_path = str(a6_session["MENU1.A6"].path)
	editor.set("_selected_name", "A01.AX")
	editor.call("_decode_selected")
	_check(not a6_editor.visible, "A6 controls are hidden for non-A6 entries")
	_check(
		details.text.contains("Shape: 10 x 32 = 320")
		and details.text.contains("1280 bytes / 0x500")
		and details.text.contains("Non-FF target cells: 2 / 320")
		and details.text.contains("(0,0)")
		and details.text.contains("(0,4)")
		and details.text.contains("Shared draw records: 2 x 0x1C bytes")
		and details.text.contains("Destination rectangles within 640x400: 2 / 2")
		and details.text.contains("Source rectangles within native surface 8 (2688x864): 2 / 2")
		and details.text.contains("surface 8 (2688x864) -> surface 0 (640x400)")
		and details.text.contains("EVENTB02/EVENTB14 routes load their AN MMO into surface 8")
		and details.text.contains("detached inspector has no selected MES producer")
		and details.text.contains("native animation timing remains unresolved"),
		"Image Editor exposes confirmed AX streams and draw records without presenting them as standalone pixels"
	)
	_check(editor.get("_decoded_image") == null, "AX inspection does not pretend the stream is a decoded image")
	var ax_inspector: HFlowContainer = editor.get_node("Margin/Layout/Split/Right/AXInspector")
	var ax_cell_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/AXInspector/AXCellSelect")
	var ax_play_pause: Button = editor.get_node("Margin/Layout/Split/Right/AXInspector/AXPlayPause")
	var ax_restart: Button = editor.get_node("Margin/Layout/Split/Right/AXInspector/AXRestart")
	var ax_clock_summary: Label = editor.get_node("Margin/Layout/Split/Right/AXInspector/AXClockSummary")
	var ax_cell_summary: Label = editor.get_node("Margin/Layout/Split/Right/AXInspector/AXCellSummary")
	var ax_overlay: ContentToolAxDestinationOverlay = editor.get("_ax_destination_overlay")
	_check(
		ax_inspector.visible
		and ax_cell_select.item_count == 2
		and ax_overlay.size == Vector2(640, 400)
		and ax_overlay.get_dispatch_count() == 1
		and ax_overlay.get_shared_record_index(0) == 1
		and ax_overlay.get_destination_rect(0) == Rect2(Vector2(100, 120), Vector2(40, 30)),
		"AX Game Frame shows only the selected cell's stored confirmed destination reference"
	)
	_check(ax_cell_summary.text.contains("stored commands") and ax_cell_summary.text.contains("1 confirmed destination"), "AX cell summary labels structural dispatch scope")
	var ax_scheduler: KakyuAxToolScheduler = editor.get("_ax_tool_scheduler")
	var ax_playback_plan: Dictionary = editor.get("_ax_tool_playback_plan")
	_check(
		not ax_play_pause.disabled
		and not ax_restart.disabled
		and not bool(editor.get("_ax_tool_playing"))
		and bool(ax_scheduler.snapshot().configured)
		and str(ax_playback_plan.get("schema", "")) == "kakyu_ax_playback_plan/v2"
		and int(ax_playback_plan.frames[0].shared_record_index) == 1
		and int(ax_playback_plan.timeline.dispatch_events[0].shared_record_index) == 0
		and int(ax_playback_plan.timeline.dispatch_events[0].source_shared_record_index) == 1
		and int(ax_scheduler.snapshot().cycle_ticks) == 3
		and ax_clock_summary.text.contains("structural overview")
		and ax_clock_summary.text.contains("native cadence unconfirmed"),
		"Image Editor configures the shared AX scheduler while keeping the structural overview paused"
	)
	editor.call("_advance_ax_tool_ticks", 1)
	_check(
		int(ax_scheduler.snapshot().current_tick) == 1
		and int(ax_scheduler.snapshot().current_shared_record_index) == 0
		and ax_overlay.get_dispatch_count() == 1
		and ax_overlay.get_shared_record_index(0) == 1
		and ax_clock_summary.text.contains("current dispatch"),
		"Image Editor advances the selected AX cell through the shared deterministic tool clock"
	)
	editor.call("_on_ax_play_pause_pressed")
	_check(bool(editor.get("_ax_tool_playing")) and ax_play_pause.text == "Pause", "Image Editor exposes explicit AX Play and Pause state")
	editor.call("_on_ax_play_pause_pressed")
	_check(not bool(editor.get("_ax_tool_playing")) and ax_play_pause.text == "Play", "Image Editor pauses without discarding the shared AX scheduler state")
	editor.call("_on_ax_restart_pressed")
	_check(
		int(ax_scheduler.snapshot().current_tick) == 0
		and ax_clock_summary.text.contains("structural overview")
		and ax_overlay.get_shared_record_index(0) == 1,
		"Image Editor Restart restores tick zero and the labeled structural overview"
	)
	ax_cell_select.select(1)
	editor.call("_on_ax_cell_selected", 1)
	_check(
		ax_overlay.get_shared_record_index(0) == 0
		and ax_overlay.get_destination_rect(0) == Rect2(Vector2(10, 20), Vector2(32, 24)),
		"AX cell selection switches destination references and resets the shared tool timeline"
	)
	var selected_loop_timeline: Dictionary = editor.get("_ax_tool_timeline")
	_check(
		bool(ax_scheduler.snapshot().configured)
		and (selected_loop_timeline.get("dispatch_events", []) as Array).size() == 2,
		"Image Editor compiles bounded AX loop controls through the common scheduler"
	)

	# ME-02: the AX timeline editor panel, on the same selected cell (0,4) (the
	# count-2 loop dispatching shared record #0, 32x24 at destination 10,20).
	var ax_editor: VBoxContainer = editor.get_node("Margin/Layout/Split/Right/AXEditor")
	var ax_command_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/AXEditor/CommandRow/AXCommandSelect")
	var ax_opcode_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/AXEditor/CommandRow/AXOpcodeSelect")
	var ax_operand: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/CommandRow/AXOperand")
	var ax_command_up: Button = editor.get_node("Margin/Layout/Split/Right/AXEditor/CommandRow/AXCommandUp")
	var ax_command_down: Button = editor.get_node("Margin/Layout/Split/Right/AXEditor/CommandRow/AXCommandDown")
	var ax_record_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXRecordSelect")
	var ax_record_type: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXRecordType")
	var ax_source_x: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXSourceX")
	var ax_source_y: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXSourceY")
	var ax_width: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXWidth")
	var ax_height: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXHeight")
	var ax_destination_x: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXDestinationX")
	var ax_destination_y: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXDestinationY")
	var ax_diagnostics: Label = editor.get_node("Margin/Layout/Split/Right/AXEditor/StageRow/AXDiagnostics")
	_check(ax_editor.visible, "AX editor panel is visible while an AX entry is inspected")

	ax_command_select.select(1)
	editor.call("_on_ax_command_selected", 1)
	_check(
		ax_record_select.selected == 0
		and int(ax_record_type.value) == 0
		and int(ax_source_x.value) == 0
		and int(ax_source_y.value) == 0
		and int(ax_width.value) == 32
		and int(ax_height.value) == 24
		and int(ax_destination_x.value) == 10
		and int(ax_destination_y.value) == 20,
		"selecting cell (0,4)'s dispatch loads shared record #0 into the record controls"
	)

	ax_destination_x.value = 110
	ax_destination_y.value = 130
	editor.call("_on_ax_record_apply_pressed")
	_check(
		int(editor.get("_ax_edit_count")) == 1
		and ax_overlay.get_destination_rect(0) == Rect2(Vector2(110, 130), Vector2(32, 24))
		and ax_diagnostics.text.contains("1 edit(s) pending")
		and ax_diagnostics.text.contains("cell (0,4)")
		and ax_diagnostics.text.contains("byte delta +0")
		and details.text.contains("Pending timeline edits: 1"),
		"applying destination 110,130 updates the Game Frame overlay rect and the diagnostics"
	)

	ax_opcode_select.select(9)
	ax_operand.value = 1
	editor.call("_on_ax_command_insert_pressed")
	var grown_timeline: Dictionary = editor.get("_ax_tool_timeline")
	_check(
		ax_command_select.item_count == 5
		and int(editor.get("_ax_edit_count")) == 2
		and (editor.get("_ax_changed_cells") as Dictionary).has("0,4")
		and (grown_timeline.get("dispatch_events", []) as Array).size() == 4,
		"inserting a dispatch of record 1 after the loop's dispatch doubles the per-iteration dispatch events (2 -> 4)"
	)

	_check(
		ax_command_select.get_item_text(1).contains("record 0")
		and ax_command_select.get_item_text(2).contains("record 1"),
		"the inserted dispatch command lists after the loop's original dispatch"
	)
	editor.call("_on_ax_command_up_pressed")
	_check(
		ax_command_select.get_item_text(1).contains("record 1")
		and ax_command_select.get_item_text(2).contains("record 0"),
		"Move up reorders the command list and the selector reflects it"
	)
	editor.call("_on_ax_command_down_pressed")
	_check(
		ax_command_select.get_item_text(1).contains("record 0")
		and ax_command_select.get_item_text(2).contains("record 1"),
		"Move down reorders the command list back and the selector reflects it"
	)

	ax_command_select.select(4)
	editor.call("_on_ax_command_selected", 4)
	editor.call("_on_ax_command_remove_pressed")
	_check(
		status.text.contains("AX edit rejected")
		and int(editor.get("_ax_edit_count")) == 4,
		"Remove of the terminal command is refused by the writer"
	)

	ax_record_select.select(1)
	editor.call("_on_ax_record_selected", 1)
	_check(
		int(ax_record_type.value) == 1
		and int(ax_source_x.value) == 32
		and int(ax_width.value) == 40
		and int(ax_height.value) == 30
		and int(ax_destination_x.value) == 100
		and int(ax_destination_y.value) == 120,
		"selecting shared record #1 loads its stored fields"
	)
	ax_destination_x.value = 640
	ax_destination_y.value = 400
	editor.call("_on_ax_record_apply_pressed")
	_check(
		status.text.contains("AX edit rejected")
		and int(editor.get("_ax_edit_count")) == 4,
		"a destination of 640,400 with width 40 is refused"
	)

	editor.call("_on_stage_ax_pressed")
	var ax_session: Dictionary = editor.get("_session")
	_check(
		status.text.contains("AX staged and reopened")
		and ax_session.has("A01.AX")
		and str(ax_session["A01.AX"].kind) == "AX"
		and int(ax_session["A01.AX"].delta) == 5
		and (ax_session["A01.AX"].changed_cells as Array).size() == 1
		and int((ax_session["A01.AX"].changed_cells[0] as Dictionary).row) == 0
		and int((ax_session["A01.AX"].changed_cells[0] as Dictionary).column) == 4
		and str(ax_session["A01.AX"].audit.schema) == "kakyu_ax_write_audit/v1"
		and str(ax_session["A01.AX"].compatibility) == "original_engine_unverified",
		"Stage AX puts a kind AX item in the session with delta equal to the byte growth and audit.changed_cells naming (0,4)"
	)
	var ax_staged_sha256 := str(ax_session["A01.AX"].sha256)
	var collected_ax: Dictionary = editor.call("_collect_session_paths")
	_check(collected_ax.ok, "_collect_session_paths accepts the staged AX kind through its generic branch")

	var ax_overlay_root := TEST_ROOT + "/ax_mod"
	editor.call("_on_overlay_directory_selected", ax_overlay_root)
	var ax_overlay_manifest := OverlayPackageScript.new().load_manifest(ax_overlay_root)
	var ax_replacement_record: Dictionary = {}
	if ax_overlay_manifest.ok:
		for record in ax_overlay_manifest.manifest.replacements:
			if str(record.target_entry) == "A01.AX":
				ax_replacement_record = record
	var ax_replacement_path := ax_overlay_root.path_join(str(ax_replacement_record.get("replacement_path", "")))
	_check(
		ax_overlay_manifest.ok
		and not ax_replacement_record.is_empty()
		and FileAccess.get_sha256(ax_replacement_path) == ax_staged_sha256,
		"saving the session to a fresh overlay directory writes an AX replacement whose sha256 equals the staged file's"
	)

	editor.call("_on_remove_replacement_pressed")
	editor.call("_decode_selected")
	_check(
		details.text.contains("Resolved source: overlay")
		and int((editor.get("_ax_document") as Dictionary).shared_records[0].destination_x) == 110
		and int((editor.get("_ax_document") as Dictionary).shared_records[0].destination_y) == 130,
		"reloading the overlay shows the edited record in the inspector (destination 110,130)"
	)

	ax_cell_select.select(1)
	editor.call("_on_ax_cell_selected", 1)
	_check(
		ax_overlay.get_shared_record_index(0) == 0
		and ax_overlay.get_destination_rect(0) == Rect2(Vector2(110, 130), Vector2(32, 24)),
		"the reloaded cell (0,4) still resolves its single drawable dispatch to record #0"
	)
	ax_record_select = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXRecordSelect")
	ax_record_type = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXRecordType")
	ax_source_x = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXSourceX")
	ax_source_y = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXSourceY")
	ax_width = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXWidth")
	ax_height = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXHeight")
	ax_destination_x = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXDestinationX")
	ax_destination_y = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXDestinationY")
	ax_record_select.select(0)
	editor.call("_on_ax_record_selected", 0)
	_check(
		int(ax_destination_x.value) == 110 and int(ax_destination_y.value) == 130,
		"the reloaded record controls show the overlay-resolved destination"
	)
	ax_destination_x.value = 200
	ax_destination_y.value = 200
	editor.call("_on_ax_record_apply_pressed")
	_check(
		int(editor.get("_ax_edit_count")) == 1
		and ax_overlay.get_destination_rect(0) == Rect2(Vector2(200, 200), Vector2(32, 24)),
		"a further edit against the reloaded baseline is tracked"
	)
	editor.call("_on_revert_ax_pressed")
	_check(
		int(editor.get("_ax_edit_count")) == 0
		and ax_overlay.get_destination_rect(0) == Rect2(Vector2(110, 130), Vector2(32, 24))
		and details.text.contains("Pending timeline edits: none"),
		"Revert restores the original (overlay-reloaded) document"
	)

	editor.call("_on_import_pressed")
	_check(status.text.contains("PNG import does not apply"), "the PNG-import guard still refuses AX")

	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(editor.size == Vector2(1024, 640) and _controls_fit(editor), "AX structural preview fits the shared minimum desktop size")
	get_window().size = original_window_size
	await get_tree().process_frame
	editor.call("_on_export_pressed")
	_check(status.text.contains("no directly decoded PNG"), "Image Editor blocks AX PNG export")
	editor.set("_selected_name", "TEST.MMO")
	editor.call("_decode_selected")
	_check(not ax_inspector.visible and ax_overlay.get_dispatch_count() == 0 and not bool(ax_scheduler.snapshot().configured), "AX scheduler and structural controls clear before pixel-image preview")
	var asset_preview: TextureRect = editor.get_node("Margin/Layout/Split/Right/PreviewTabs/AssetView/Preview")
	var game_preview: ContentToolGamePreview = editor.get_node("Margin/Layout/Split/Right/PreviewTabs/GameFrame/GamePreview")
	_check(asset_preview.texture != null, "Asset View displays the decoded source image")
	_check(game_preview.get_game_viewport().size == Vector2i(640, 400), "Image Editor embeds the shared fixed game-frame viewport")
	var centered_binding := game_preview.get_compositor_surface_binding()
	var centered_frame: Texture2D = game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	var source_image: Image = asset_preview.texture.get_image()
	_check(
		centered_binding.schema == "kakyu_tool_game_preview_compositor_binding/v1"
		and centered_binding.surface_index == 0
		and game_preview.get_frame_content_rect() == Rect2(Vector2.ZERO, Vector2(640, 400))
		and TestHelpers.color_close(centered_frame.get_image().get_pixel(319, 199), source_image.get_pixel(0, 0)),
		"Game Frame centers decoded pixels through the shared 640x400 compositor"
	)
	_check(centered_frame != asset_preview.texture, "Asset View retains source pixels while Game Frame owns a detached composed snapshot")
	var frame_x: SpinBox = editor.get_node("Margin/Layout/Split/Right/PreviewTabs/GameFrame/Placement/FrameX")
	var frame_y: SpinBox = editor.get_node("Margin/Layout/Split/Right/PreviewTabs/GameFrame/Placement/FrameY")
	frame_x.value = 12
	frame_y.value = 34
	var placed_frame: Texture2D = game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		TestHelpers.color_close(placed_frame.get_image().get_pixel(12, 34), source_image.get_pixel(0, 0))
		and TestHelpers.color_close(placed_frame.get_image().get_pixel(11, 34), Color.BLACK),
		"Game Frame exposes explicit logical X/Y placement through the compositor"
	)
	frame_x.value = -1
	frame_y.value = -1
	var cropped_result: Dictionary = editor.call("_present_decoded_game_frame")
	var cropped_frame: Texture2D = game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		cropped_result.ok
		and cropped_result.source_position == Vector2i(1, 1)
		and cropped_result.destination_position == Vector2i.ZERO
		and cropped_result.visible_size == Vector2i.ONE
		and TestHelpers.color_close(cropped_frame.get_image().get_pixel(0, 0), source_image.get_pixel(1, 1)),
		"Game Frame clips a negatively placed source at the logical surface boundary"
	)
	frame_x.value = 1000
	frame_y.value = 1000
	var offscreen_result: Dictionary = editor.call("_present_decoded_game_frame")
	var offscreen_frame: Texture2D = game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		offscreen_result.ok
		and offscreen_result.visible_size == Vector2i.ZERO
		and TestHelpers.color_close(offscreen_frame.get_image().get_pixel(0, 0), Color.BLACK),
		"a fully offscreen source produces a valid empty logical frame"
	)
	editor.call("_on_center_frame_pressed")
	var recentered_frame: Texture2D = game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		TestHelpers.color_close(recentered_frame.get_image().get_pixel(319, 199), source_image.get_pixel(0, 0)),
		"Game Frame can restore centered compositor placement"
	)

	editor.call("_on_replacement_path_selected", mismatch_path)
	_check(editor.get("_session").size() == 1 and editor.get("_session").has("MENU1.A6"), "dimension-mismatched PNG is rejected without disturbing the A6 edit")
	editor.call("_on_replacement_path_selected", replacement_path)
	var session: Dictionary = editor.get("_session")
	_check(session.size() == 2 and session.has("TEST.MMO"), "verified MMO replacement joins the session")
	_check(
		session["TEST.MMO"].header_origin == "target_template_preserved"
		and session["TEST.MMO"].header_profile == "standard_mirrored_dimensions"
		and session["TEST.MMO"].compatibility == "original_engine_compatible",
		"MMO session distinguishes preserved standard target headers from generated output"
	)
	_check(not session["TEST.MMO"].has("data"), "pending session stores a cache path instead of image bytes")
	_check(FileAccess.file_exists(session["TEST.MMO"].path), "encoded MMO payload is staged in the user cache")
	var loaded: Dictionary = editor.call("_load_pending", "TEST.MMO")
	var decoded := MmoCodecScript.new().decode_image(loaded.data) if loaded.ok else {"ok": false}
	_check(decoded.ok and decoded.image.get_data() == replacement_image.get_data(), "staged MMO decodes to replacement pixels")
	var staged_bytes: PackedByteArray = loaded.data
	_write_bytes(str(session["TEST.MMO"].path), PackedByteArray([1, 2, 3]))
	_check(not editor.call("_load_pending", "TEST.MMO").ok, "changed session cache payload is rejected")
	_write_bytes(str(session["TEST.MMO"].path), staged_bytes)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "PNG staging never changes the source ARC")
	var collected: Dictionary = editor.call("_collect_session_paths")
	_check(
		collected.ok
		and collected.paths["TEST.MMO"] is String
		and collected.paths["MENU1.A6"] is String
		and collected.compatibility == "original_engine_compatible",
		"save collection streams engine-compatible MMO and A6 cache paths"
	)
	editor.set("_selected_name", "CHARA.DAT")
	editor.call("_on_replacement_path_selected", lossy_strip_path)
	var comparison: Window = editor.get_node("QuantizationComparison")
	var comparison_before: TextureRect = editor.get_node("QuantizationComparison/Margin/Layout/Images/Before/BeforeTexture")
	var comparison_after: TextureRect = editor.get_node("QuantizationComparison/Margin/Layout/Images/After/AfterTexture")
	var comparison_summary: Label = editor.get_node("QuantizationComparison/Margin/Layout/QuantizationSummary")
	var comparison_candidate: Dictionary = editor.get("_quantization_candidate")
	var rejected_candidate_paths: Array[String] = []
	for descriptor in (comparison_candidate.get("files", {}) as Dictionary).values():
		rejected_candidate_paths.append(str((descriptor as Dictionary).path))
	_check(
		editor.get("_session").size() == 2
		and comparison.visible
		and not comparison_candidate.is_empty()
		and comparison_before.texture != null
		and comparison_after.texture != null
		and comparison_before.texture.get_image().get_data() != comparison_after.texture.get_image().get_data()
		and comparison_summary.text.contains("changed pixel(s)")
		and comparison_summary.text.contains("RGB MAE")
		and status.text.contains("review the measured before/after comparison"),
		"Image Editor opens a measured before/after comparison while keeping lossy DAT/PAL imports unstaged"
	)
	editor.call("_on_reject_quantization_pressed")
	var rejected_files_removed := true
	for candidate_path in rejected_candidate_paths:
		rejected_files_removed = rejected_files_removed and not FileAccess.file_exists(candidate_path)
	_check(
		(editor.get("_quantization_candidate") as Dictionary).is_empty()
		and not comparison.visible
		and editor.get("_session").size() == 2
		and rejected_files_removed,
		"rejecting quantization removes only transient candidate files and preserves the pending session"
	)
	editor.call("_on_replacement_path_selected", lossy_strip_path)
	comparison_candidate = editor.get("_quantization_candidate")
	_check(not comparison_candidate.is_empty() and comparison.visible, "lossy DAT/PAL comparison can be reopened after rejection")
	var changed_candidate_descriptor: Dictionary = comparison_candidate.files["CHARA.PAL"]
	_write_bytes(str(changed_candidate_descriptor.path), PackedByteArray([1, 2, 3]))
	editor.call("_on_accept_quantization_pressed")
	_check(
		(editor.get("_quantization_candidate") as Dictionary).is_empty()
		and editor.get("_session").size() == 2
		and not FileAccess.file_exists(str(changed_candidate_descriptor.path))
		and status.text.contains("Quantization approval rejected:"),
		"quantization approval rechecks cached payload hashes and removes a changed candidate without touching the session"
	)
	editor.call("_on_replacement_path_selected", lossy_strip_path)
	editor.call("_on_accept_quantization_pressed")
	session = editor.get("_session")
	_check(
		session.size() == 3
		and session.has("CHARA.DAT")
		and session["CHARA.DAT"].authoring_origin == "quantization_approved"
		and int(session["CHARA.DAT"].quantization_diagnostics.changed_pixel_count) > 0
		and (editor.get("_quantization_candidate") as Dictionary).is_empty()
		and not comparison.visible
		and details.text.contains("Quantization approval: accepted")
		and status.text.contains("quantization accepted and staged")
		and FileAccess.get_sha256(archive_path) == source_sha,
		"accepting the reviewed result promotes its exact hash-bound DAT/PAL pair into the pending session"
	)
	editor.call("_on_replacement_path_selected", strip_path)
	session = editor.get("_session")
	_check(session.size() == 3 and session["CHARA.DAT"].files.size() == 2, "DAT/PAL import stages one paired logical replacement")
	_check(
		session["CHARA.DAT"].diagnostics_schema == ContentCoreVersionScript.DAT_PAL_DIAGNOSTICS_SCHEMA
		and int(session["CHARA.DAT"].quantization_diagnostics.changed_pixel_count) == 0
		and details.text.contains("Palette use:")
		and details.text.contains("Index zero:")
		and details.text.contains("Quantization: 0 changed pixels"),
		"Image Editor exposes decoded palette use, index-zero alpha, and pending import diagnostics"
	)
	var strip_frame: Texture2D = game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture
	_check(
		game_preview.get_compositor_surface_binding().surface_index == 0
		and not TestHelpers.color_close(strip_frame.get_image().get_pixel(0, 184), Color.BLACK)
		and TestHelpers.color_close(strip_frame.get_image().get_pixel(0, 183), Color.BLACK),
		"Game Frame composes a DAT/PAL strip at native centered game coordinates"
	)
	var dat_path := str(session["CHARA.DAT"].files["CHARA.DAT"].path)
	var pal_path := str(session["CHARA.DAT"].files["CHARA.PAL"].path)
	_check(FileAccess.file_exists(dat_path) and FileAccess.file_exists(pal_path), "DAT and PAL payloads are both cached")
	collected = editor.call("_collect_session_paths")
	_check(
		collected.ok
		and collected.paths.size() == 4
		and collected.bound_files.size() == 4
		and str(collected.bound_files["TEST.MMO"].sha256) == FileAccess.get_sha256(str(collected.paths["TEST.MMO"])),
		"mixed image session collects and SHA-binds MMO, paired DAT/PAL, and A6 entries"
	)
	_check(collected.ok and collected.compatibility == "remake_only", "unverified DAT/PAL pair safely downgrades mixed overlay compatibility")

	editor.call("_on_overlay_directory_selected", overlay_root)
	var loaded_overlay := OverlayPackageScript.new().load_manifest(overlay_root)
	_check(loaded_overlay.ok and loaded_overlay.manifest.replacements.size() == 4, "image editor publishes the full mixed overlay session")
	if loaded_overlay.ok:
		var records: Dictionary = {}
		for record in loaded_overlay.manifest.replacements:
			records[str(record.target_entry)] = record
		var overlay_data := FileAccess.get_file_as_bytes(overlay_root.path_join(str(records["TEST.MMO"].replacement_path)))
		var overlay_decoded := MmoCodecScript.new().decode_image(overlay_data)
		_check(records["TEST.MMO"].compatibility == "remake_only", "mixed overlay applies the conservative compatibility")
		_check(overlay_decoded.ok and overlay_decoded.image.get_data() == replacement_image.get_data(), "overlay contains the verified MMO pixels")
		var overlay_dat := FileAccess.get_file_as_bytes(overlay_root.path_join(str(records["CHARA.DAT"].replacement_path)))
		var overlay_pal := FileAccess.get_file_as_bytes(overlay_root.path_join(str(records["CHARA.PAL"].replacement_path)))
		var overlay_pair := DatPalCodecScript.new().decode_image(overlay_dat, overlay_pal)
		_check(overlay_pair.ok and _visible_strip_equal(overlay_pair.image, replacement_strip), "overlay contains the verified DAT/PAL pixels")
		var overlay_a6 := A6LayoutScript.new().inspect(FileAccess.get_file_as_bytes(overlay_root.path_join(str(records["MENU1.A6"].replacement_path))))
		_check(overlay_a6.ok and int(overlay_a6.records[0].right) == 9, "overlay contains the verified A6 rectangle edit")

	var export_changed_source := pristine_archive_bytes.duplicate()
	export_changed_source[export_changed_source.size() - 1] ^= 0x01
	_write_bytes(archive_path, export_changed_source)
	editor.call("_on_export_arc_path_selected", changed_source_output_arc_path)
	_check(
		not FileAccess.file_exists(changed_source_output_arc_path)
		and (editor.get_node("Margin/Layout/StatusLabel") as Label).text.contains("Source ARC changed after it was opened"),
		"image ARC export rejects source bytes changed after the editor captured its open-time fingerprint"
	)
	_write_bytes(archive_path, pristine_archive_bytes)
	_check(FileAccess.get_sha256(archive_path) == source_sha, "image export source-mutation fixture restores the source ARC")
	editor.call("_on_export_arc_path_selected", output_arc_path)
	var rebuilt := ArcReaderScript.new()
	_check(rebuilt.open(output_arc_path), "image editor ARC copy reopens")
	var image_provenance := ArcProvenanceScript.new().load_sidecar(output_arc_path)
	_check(image_provenance.get("ok", false) and image_provenance.provenance.declared_compatibility == "remake_only", "image ARC export publishes portable conservative provenance")
	if rebuilt.is_open():
		var rebuilt_decoded := MmoCodecScript.new().decode_image(rebuilt.read_entry("TEST.MMO"))
		_check(rebuilt_decoded.ok and rebuilt_decoded.image.get_data() == replacement_image.get_data(), "ARC copy contains the verified MMO pixels")
		var rebuilt_pair := DatPalCodecScript.new().decode_image(rebuilt.read_entry("CHARA.DAT"), rebuilt.read_entry("CHARA.PAL"))
		_check(rebuilt_pair.ok and _visible_strip_equal(rebuilt_pair.image, replacement_strip), "ARC copy contains the verified DAT/PAL pixels")
		var rebuilt_a6 := A6LayoutScript.new().inspect(rebuilt.read_entry("MENU1.A6"))
		_check(rebuilt_a6.ok and int(rebuilt_a6.records[0].right) == 9, "ARC copy contains the verified A6 rectangle edit")
		rebuilt.close()
	_check(editor.get("_session").size() == 3, "successful image saves preserve the mixed pending session")
	_check(FileAccess.get_sha256(archive_path) == source_sha, "image saves keep the source ARC byte-identical")

	var staged_path := str(session["TEST.MMO"].path)
	editor.call("_on_remove_replacement_pressed")
	_check(editor.get("_session").size() == 2, "pending DAT/PAL pair can be removed as one logical replacement")
	_check(not FileAccess.file_exists(dat_path) and not FileAccess.file_exists(pal_path), "removing DAT/PAL clears both cache files")
	editor.set("_selected_name", "TEST.MMO")
	editor.call("_on_remove_replacement_pressed")
	_check(editor.get("_session").size() == 1, "pending MMO replacement can be removed independently")
	_check(not FileAccess.file_exists(staged_path), "removing a replacement deletes its session cache file")
	editor.set("_selected_name", "MENU1.A6")
	editor.call("_on_remove_replacement_pressed")
	_check(editor.get("_session").is_empty(), "pending A6 replacement can be removed")
	_check(not FileAccess.file_exists(a6_path), "removing an A6 replacement deletes its session cache file")
	editor.call("_on_clear_overlay_pressed")
	_check(
		str(editor.get("_overlay_root")).is_empty()
		and int(a6_right.value) == 4
		and details.text.contains("Resolved source: original_arc"),
		"clearing the loaded overlay returns the A6 preview to original ARC bytes"
	)

	editor.queue_free()
	await get_tree().process_frame
	await _test_startup_selection()
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _test_startup_selection() -> void:
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	var source_root := absolute_root.path_join("selection_source")
	var workspace_root := absolute_root.path_join("selection_workspace")
	DirAccess.make_dir_recursive_absolute(source_root)
	var archive_path := source_root.path_join("data.arc")
	var image := _test_image(Color(1, 0, 0), Color(0, 1, 0))
	var encoded: Dictionary = MmoCodecScript.new().encode_image(image)
	var mmo_data: PackedByteArray = encoded.data
	SyntheticArc.write_arc(archive_path, [
		{"name": "FIRST.MMO", "data": mmo_data},
		{"name": "SECOND.MMO", "data": mmo_data},
	])
	var foreign_archive_path := source_root.path_join("mes.arc")
	SyntheticArc.write_arc(foreign_archive_path, [
		{"name": "FOREIGN.MES", "data": "foreign".to_ascii_buffer()},
	])
	var archive_sha := FileAccess.get_sha256(archive_path)
	var foreign_archive_sha := FileAccess.get_sha256(foreign_archive_path)
	var archives := [
		{"archive": "data.arc", "sha256": archive_sha, "required": true},
		{"archive": "mes.arc", "sha256": foreign_archive_sha, "required": false},
	]
	var project := {
		"schema": ContentCoreVersionScript.CONTENT_PROJECT_SCHEMA, "project_id": "image-editor.selection.test",
		"project_version": "0.1.0", "display_name": "Image Editor Selection Test", "project_revision": 1,
		"content_core": {"minimum_version": ContentCoreVersionScript.CORE_VERSION, "maximum_exclusive": "1.0.0"},
		"source_content_set": {
			"profile_id": "synthetic-test",
			"fingerprint_sha256": ContentProjectScript.compute_content_set_fingerprint(archives),
			"archives": archives,
		},
		"target_archives": ["data.arc", "mes.arc"], "compatibility_objective": "mixed", "dependencies": [],
		"event_player": {"catalog_id": "kakyu-original-events", "presets": []}, "overlay_manifest": "manifest.json",
	}
	var workspace := ContentWorkspaceScript.new()
	var created := workspace.create(workspace_root, source_root, project)
	_check(created.get("ok", false), "image editor selection fixture creates a named workspace")
	var snapshot := workspace.get_snapshot()
	workspace.close()

	var reader := ArcReaderScript.new()
	reader.open(archive_path)
	var entry_sha := reader.get_entry_fingerprint("FIRST.MMO")
	var second_entry_sha := reader.get_entry_fingerprint("SECOND.MMO")
	reader.close()
	var foreign_reader := ArcReaderScript.new()
	foreign_reader.open(foreign_archive_path)
	var foreign_entry_sha := foreign_reader.get_entry_fingerprint("FOREIGN.MES")
	foreign_reader.close()

	var document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "data.arc", "entry": "FIRST.MMO", "source_entry_sha256": entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(document.get("ok", false), "image editor selection fixture builds a content selection for FIRST.MMO")
	var selection_path := absolute_root.path_join("selection.json")
	_write_text(selection_path, JSON.stringify(document, "", true, true) + "\n")

	var selection_editor: Control = ImageEditorScene.instantiate()
	add_child(selection_editor)
	await get_tree().process_frame
	selection_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root, "--selection", selection_path,
	]))
	_check(
		str(selection_editor.get("_selected_name")) == "FIRST.MMO"
		and (selection_editor.get("status_label") as Label).text == "Selection from arc_browser: FIRST.MMO"
		and (selection_editor.get("preview") as TextureRect).texture != null,
		"Image editor startup with a selection opens data.arc, selects FIRST.MMO, and decodes its normal preview"
	)
	selection_editor.queue_free()
	await get_tree().process_frame

	var bad_last_character := "0" if not second_entry_sha.ends_with("0") else "1"
	var wrong_hash_document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "data.arc", "entry": "SECOND.MMO",
			"source_entry_sha256": second_entry_sha.substr(0, 63) + bad_last_character,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(wrong_hash_document.get("ok", false), "image editor selection fixture builds a wrong-hash content selection")
	var wrong_hash_path := absolute_root.path_join("wrong-hash-selection.json")
	_write_text(wrong_hash_path, JSON.stringify(wrong_hash_document, "", true, true) + "\n")

	var wrong_hash_editor: Control = ImageEditorScene.instantiate()
	add_child(wrong_hash_editor)
	await get_tree().process_frame
	wrong_hash_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root, "--selection", wrong_hash_path,
	]))
	_check(
		str((wrong_hash_editor.get("status_label") as Label).text).begins_with("Selection rejected:"),
		"Image editor rejects a wrong-hash selection with a status error"
	)
	wrong_hash_editor.queue_free()
	await get_tree().process_frame

	var foreign_document := ContentSelectionScript.new().build(
		snapshot,
		{
			"archive": "mes.arc", "entry": "FOREIGN.MES", "source_entry_sha256": foreign_entry_sha,
			"catalog_id": "", "event_id": "", "preset_id": "",
		},
		"arc_browser"
	)
	_check(foreign_document.get("ok", false), "image editor selection fixture builds a foreign-archive content selection")
	var foreign_path := absolute_root.path_join("foreign-selection.json")
	_write_text(foreign_path, JSON.stringify(foreign_document, "", true, true) + "\n")

	var foreign_editor: Control = ImageEditorScene.instantiate()
	add_child(foreign_editor)
	await get_tree().process_frame
	foreign_editor.call("_apply_startup_arguments", PackedStringArray([
		"--content-set", source_root, "--workspace", workspace_root, "--selection", foreign_path,
	]))
	_check(
		str((foreign_editor.get("status_label") as Label).text) == "Selection rejected: mes.arc does not open in the Image and Animation ARC Editor."
		and str((foreign_editor.get("archive_label") as Label).text).replace("\\", "/").ends_with("data.arc"),
		"Image editor rejects a foreign-archive selection with a status error and opens the default archive"
	)
	foreign_editor.queue_free()
	await get_tree().process_frame


func _test_image(left: Color, right: Color) -> Image:
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, left)
	image.set_pixel(1, 0, right)
	image.set_pixel(0, 1, right)
	image.set_pixel(1, 1, left)
	return image


func _ax_binding_fixture() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(0x538)
	data.fill(0)
	_write_ax_record(data, 0x500, 0, 0, 0, 32, 24, 10, 20)
	_write_ax_record(data, 0x51C, 1, 32, 0, 40, 30, 100, 120)
	for index in range(320):
		data.encode_u32(index * 4, data.size())
		if index == 0:
			data.append_array(PackedByteArray([1, 3, 0, 0, 0, 9, 1, 0, 0, 0, 0xFF]))
		elif index == 4:
			data.append_array(PackedByteArray([5, 2, 0, 0, 0, 9, 0, 0, 0, 0, 6, 0xFF]))
		else:
			data.append(0xFF)
	return data


func _write_ax_record(data: PackedByteArray, offset: int, dispatch_type: int, source_x: int, source_y: int, width: int, height: int, destination_x: int, destination_y: int) -> void:
	var values := [dispatch_type, source_x, source_y, width, height, destination_x, destination_y]
	for index in range(values.size()):
		data.encode_u32(offset + index * 4, int(values[index]))


func _strip_image(left: Color, right: Color) -> Image:
	var image := Image.create(640, 32, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, left)
	image.set_pixel(1, 0, right)
	return image


func _visible_strip_equal(left: Image, right: Image) -> bool:
	var left_data := left.get_data()
	var right_data := right.get_data()
	for offset in range(0, left_data.size(), 4):
		if left_data[offset + 3] != right_data[offset + 3]:
			return false
		if left_data[offset + 3] == 255 and left_data.slice(offset, offset + 3) != right_data.slice(offset, offset + 3):
			return false
	return true


func _controls_fit(editor: Control) -> bool:
	var margin: Control = editor.get_node("Margin")
	var layout: Control = editor.get_node("Margin/Layout")
	var editor_rect := Rect2(Vector2.ZERO, editor.size)
	return editor_rect.encloses(margin.get_rect()) and margin.get_rect().size.y >= layout.get_combined_minimum_size().y


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
