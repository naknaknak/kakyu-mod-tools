extends Control

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")
const DatPalCodecScript := preload("res://content_core/dat_pal_codec.gd")
const A6LayoutScript := preload("res://content_core/a6_layout.gd")
const A6RegionOverlayScript := preload("res://tools/content_suite/apps/a6_region_overlay.gd")
const AxDwordStreamScript := preload("res://content_core/ax_dword_stream.gd")
const AxAnimationScript := preload("res://content_core/ax_animation.gd")
const AxWriterScript := preload("res://content_core/ax_writer.gd")
const AxToolSchedulerScript := preload("res://content_core/ax_tool_scheduler.gd")
const AxPlaybackPlanScript := preload("res://content_core/ax_playback_plan.gd")
const AxDestinationOverlayScript := preload("res://tools/content_suite/apps/ax_destination_overlay.gd")
const ContentResolverScript := preload("res://content_core/content_resolver.gd")
const ContentLaunchContextScript := preload("res://content_core/content_launch_context.gd")
const ContentSelectionScript := preload("res://content_core/content_selection.gd")
const LogicalSurfaceCompositorScript := preload("res://content_core/logical_surface_compositor.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const ToolWindowProfileScript := preload("res://tools/content_suite/tool_window_profile.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const SESSION_PARENT := "user://content/image_editor_sessions"
const AX_TOOL_TICK_SECONDS := 1.0 / 60.0
const AX_DISPATCH_OPCODE := 9
const AX_U32_OPERAND_OPCODES := [1, 2, 5, 7]
const AX_OPCODE_ITEMS: Array[Dictionary] = [
	{"label": "00 control", "opcode": 0x00},
	{"label": "01 control u32", "opcode": 0x01},
	{"label": "02 control u32", "opcode": 0x02},
	{"label": "03 reset to start", "opcode": 0x03},
	{"label": "04 stop", "opcode": 0x04},
	{"label": "05 loop begin (count)", "opcode": 0x05},
	{"label": "06 loop repeat", "opcode": 0x06},
	{"label": "07 control u32", "opcode": 0x07},
	{"label": "08 control", "opcode": 0x08},
	{"label": "dispatch shared record", "opcode": AX_DISPATCH_OPCODE},
	{"label": "FF stop", "opcode": 0xFF},
]
const AX_OPCODE_DISPATCH_ITEM_INDEX := 9

@onready var archive_label: Label = %ArchiveLabel
@onready var filter_edit: LineEdit = %FilterEdit
@onready var entry_tree: Tree = %EntryTree
@onready var export_button: Button = $Margin/Layout/Toolbar/Export
@onready var import_button: Button = $Margin/Layout/SessionToolbar/Import
@onready var remove_button: Button = $Margin/Layout/SessionToolbar/Remove
@onready var preview_tabs: TabContainer = %PreviewTabs
@onready var preview: TextureRect = %Preview
@onready var game_preview: ContentToolGamePreview = %GamePreview
@onready var frame_x: SpinBox = %FrameX
@onready var frame_y: SpinBox = %FrameY
@onready var frame_footprint: Label = %FrameFootprint
@onready var details: RichTextLabel = %Details
@onready var palette_editor: HFlowContainer = %PaletteEditor
@onready var palette_entry_select: OptionButton = %PaletteEntrySelect
@onready var palette_color: ColorPickerButton = %PaletteColor
@onready var stage_palette: Button = %StagePalette
@onready var palette_summary: Label = %PaletteSummary
@onready var a6_editor: VBoxContainer = %A6Editor
@onready var a6_record_select: OptionButton = %A6RecordSelect
@onready var a6_id: SpinBox = %A6Id
@onready var a6_left: SpinBox = %A6Left
@onready var a6_top: SpinBox = %A6Top
@onready var a6_right: SpinBox = %A6Right
@onready var a6_bottom: SpinBox = %A6Bottom
@onready var stage_a6: Button = %StageA6
@onready var a6_add: Button = %A6Add
@onready var a6_duplicate: Button = %A6Duplicate
@onready var a6_remove: Button = %A6Remove
@onready var a6_move_up: Button = %A6MoveUp
@onready var a6_move_down: Button = %A6MoveDown
@onready var a6_diagnostics: Label = %A6Diagnostics
@onready var ax_inspector: HFlowContainer = %AXInspector
@onready var ax_cell_select: OptionButton = %AXCellSelect
@onready var ax_play_pause: Button = %AXPlayPause
@onready var ax_restart: Button = %AXRestart
@onready var ax_clock_summary: Label = %AXClockSummary
@onready var ax_cell_summary: Label = %AXCellSummary
@onready var ax_editor: VBoxContainer = %AXEditor
@onready var ax_command_select: OptionButton = %AXCommandSelect
@onready var ax_opcode_select: OptionButton = %AXOpcodeSelect
@onready var ax_operand: SpinBox = %AXOperand
@onready var ax_command_apply: Button = %AXCommandApply
@onready var ax_command_insert: Button = %AXCommandInsert
@onready var ax_command_remove: Button = %AXCommandRemove
@onready var ax_command_up: Button = %AXCommandUp
@onready var ax_command_down: Button = %AXCommandDown
@onready var ax_record_select: OptionButton = %AXRecordSelect
@onready var ax_record_type: SpinBox = %AXRecordType
@onready var ax_source_x: SpinBox = %AXSourceX
@onready var ax_source_y: SpinBox = %AXSourceY
@onready var ax_width: SpinBox = %AXWidth
@onready var ax_height: SpinBox = %AXHeight
@onready var ax_destination_x: SpinBox = %AXDestinationX
@onready var ax_destination_y: SpinBox = %AXDestinationY
@onready var ax_record_apply: Button = %AXRecordApply
@onready var ax_stage: Button = %AXStage
@onready var ax_revert: Button = %AXRevert
@onready var ax_diagnostics: Label = %AXDiagnostics
@onready var status_label: Label = %StatusLabel
@onready var open_dialog: FileDialog = %OpenDialog
@onready var export_dialog: FileDialog = %ExportDialog
@onready var replacement_dialog: FileDialog = %ReplacementDialog
@onready var overlay_directory_dialog: FileDialog = %OverlayDirectoryDialog
@onready var load_overlay_dialog: FileDialog = %LoadOverlayDialog
@onready var export_arc_dialog: FileDialog = %ExportArcDialog
@onready var quantization_comparison: Window = %QuantizationComparison
@onready var before_texture: TextureRect = %BeforeTexture
@onready var after_texture: TextureRect = %AfterTexture
@onready var quantization_summary: Label = %QuantizationSummary

var _reader := ArcReaderScript.new()
var _path_history := ToolPathHistoryScript.new()
var _launch_context := ContentLaunchContextScript.new()
var _codec := MmoCodecScript.new()
var _dat_pal_codec := DatPalCodecScript.new()
var _a6_layout := A6LayoutScript.new()
var _ax_dword_stream := AxDwordStreamScript.new()
var _ax_animation := AxAnimationScript.new()
var _ax_writer := AxWriterScript.new()
var _image_entries: Array[Dictionary] = []
var _selected_name := ""
var _decoded_image: Image
var _session: Dictionary = {}
var _entry_items: Dictionary = {}
var _session_root := ""
var _updating_frame_position := false
var _palette_document: Dictionary = {}
var _palette_dat_data := PackedByteArray()
var _palette_pal_data := PackedByteArray()
var _updating_palette_controls := false
var _a6_document: Dictionary = {}
var _a6_data := PackedByteArray()
var _a6_selected_record_index := 0
var _updating_a6_controls := false
var _a6_region_overlay: ContentToolA6RegionOverlay
var _ax_document: Dictionary = {}
var _ax_cell_stream_indices: Array[int] = []
var _ax_destination_overlay: ContentToolAxDestinationOverlay
var _ax_tool_scheduler := AxToolSchedulerScript.new()
var _ax_playback_planner := AxPlaybackPlanScript.new()
var _ax_tool_timeline: Dictionary = {}
var _ax_tool_playback_plan: Dictionary = {}
var _ax_drawable_records_by_index: Dictionary = {}
var _ax_structural_records: Array = []
var _ax_tool_playing := false
var _ax_showing_structural_overview := false
var _ax_source_data := PackedByteArray()
var _ax_edited_document: Dictionary = {}
var _ax_edit_count := 0
var _ax_changed_cells: Dictionary = {}
var _ax_changed_records: Dictionary = {}
var _ax_details_base_text := ""
var _ax_selected_row := -1
var _ax_selected_column := -1
var _ax_selected_command_index := -1
var _ax_selected_record_index := -1
var _updating_ax_command_controls := false
var _updating_ax_record_controls := false
var _resolver := ContentResolverScript.new()
var _overlay_package := OverlayPackageScript.new()
var _archive_sha256 := ""
var _overlay_root := ""
var _overlay_targets: Dictionary = {}
var _restoring_tree_selection := false
var _surface_compositor := LogicalSurfaceCompositorScript.new()
var _quantization_candidate: Dictionary = {}


func _ready() -> void:
	ToolWindowProfileScript.apply(get_window())
	_session_root = ProjectSettings.globalize_path(SESSION_PARENT).simplify_path().path_join(
		"%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	entry_tree.set_column_title(0, "Asset entry")
	entry_tree.set_column_title(1, "Format")
	entry_tree.set_column_title(2, "Bytes / session")
	entry_tree.set_column_expand(0, true)
	entry_tree.set_column_expand(1, false)
	entry_tree.set_column_expand(2, false)
	entry_tree.set_column_custom_minimum_width(1, 90)
	entry_tree.set_column_custom_minimum_width(2, 90)
	preview_tabs.set_tab_title(0, "Asset View")
	preview_tabs.set_tab_title(1, "Game Frame")
	game_preview.set_input_forwarding_enabled(false)
	game_preview.set_frame_content_mode(ContentToolGamePreview.FrameContentMode.NATIVE_CENTERED)
	_a6_region_overlay = A6RegionOverlayScript.new()
	game_preview.get_overlay_root().add_child(_a6_region_overlay)
	_a6_region_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ax_destination_overlay = AxDestinationOverlayScript.new()
	game_preview.get_overlay_root().add_child(_ax_destination_overlay)
	_ax_destination_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ax_opcode_select.clear()
	for item in AX_OPCODE_ITEMS:
		ax_opcode_select.add_item(str(item.label))
	game_preview.preview_pointer_moved.connect(_on_game_preview_pointer_moved)
	game_preview.preview_pointer_pressed.connect(_on_game_preview_pointer_pressed)
	set_process(false)
	_path_history.apply_source_dialog(open_dialog)
	_update_selection_actions()
	var arguments := OS.get_cmdline_user_args()
	_apply_startup_arguments(arguments)


func _process(delta: float) -> void:
	if not _ax_tool_playing:
		return
	_apply_ax_scheduler_result(_ax_tool_scheduler.advance_seconds(delta, 240))


func _apply_startup_arguments(arguments: PackedStringArray) -> void:
	var startup := _launch_context.activate(arguments)
	if not startup.ok:
		status_label.text = str(startup.error)
		return
	if not startup.named:
		if not startup.legacy_arguments.is_empty():
			_open_archive(str(startup.legacy_arguments[0]))
		return
	var selection_document := {}
	var selection_rejected := ""
	var selection_path := _launch_context.get_selection_path()
	if not selection_path.is_empty():
		var selection_contract := ContentSelectionScript.new()
		var read_result := selection_contract.read_path(selection_path)
		if not read_result.get("ok", false):
			status_label.text = "Selection rejected: %s" % str(read_result.get("error", ""))
			return
		var validated := selection_contract.validate_for_workspace(
			read_result.document, _launch_context.get_snapshot()
		)
		if not validated.get("ok", false):
			status_label.text = "Selection rejected: %s" % str(validated.get("error", ""))
			return
		var candidate_archive := str((read_result.document.selection as Dictionary).archive)
		if candidate_archive.to_lower() in ["mmo.arc", "data.arc"]:
			selection_document = read_result.document
		else:
			selection_rejected = "Selection rejected: %s does not open in the Image and Animation ARC Editor." % candidate_archive
	var preferred_names: Array[String] = ["mmo.arc", "data.arc"]
	if not selection_document.is_empty():
		preferred_names = [str((selection_document.selection as Dictionary).archive)]
	var archive_path := _launch_context.get_preferred_archive_path(preferred_names)
	if archive_path.is_empty():
		status_label.text = "Workspace has no supported image/layout ARC."
		return
	_open_archive(archive_path)
	if not _reader.is_open():
		return
	var configured := _configure_loaded_overlay(_launch_context.get_workspace_root())
	if not configured.ok:
		status_label.text = "Workspace overlay rejected: %s" % str(configured.error)
		return
	_refresh_after_overlay_change()
	if not selection_rejected.is_empty():
		status_label.text = selection_rejected
		return
	if selection_document.is_empty():
		status_label.text = "Workspace overlay active; %d image/layout target(s)." % int(configured.target_count)
		return
	var selection: Dictionary = selection_document.selection
	var entry_name := str(selection.entry)
	var entry := _reader.get_entry(entry_name)
	if entry.is_empty() or _reader.get_entry_fingerprint(entry_name) != str(selection.source_entry_sha256):
		status_label.text = "Selection rejected: entry not found or changed in the opened archive."
		return
	filter_edit.text = ""
	_rebuild_tree()
	var item: TreeItem = _entry_items.get(entry_name)
	if item == null:
		status_label.text = "Selection rejected: entry not found in the opened archive."
		return
	item.select(0)
	_selected_name = entry_name
	_decode_selected()
	status_label.text = "Selection from %s: %s" % [str((selection_document.producer as Dictionary).app), entry_name]


func _on_open_pressed() -> void:
	_path_history.apply_source_dialog(open_dialog)
	open_dialog.popup_centered_ratio(0.75)


func _on_archive_selected(path: String) -> void:
	if not _session.is_empty():
		status_label.text = "Remove pending image replacements before opening another ARC."
		return
	if not _quantization_candidate.is_empty():
		status_label.text = "Accept or reject the DAT/PAL quantization comparison before opening another ARC."
		return
	_open_archive(path)


func _open_archive(path: String) -> void:
	_clear_quantization_candidate(true)
	_resolver.close()
	_overlay_root = ""
	_overlay_targets.clear()
	_image_entries.clear()
	_entry_items.clear()
	_archive_sha256 = ""
	_clear_session_files()
	_selected_name = ""
	_decoded_image = null
	_hide_a6_editor()
	_hide_ax_inspector()
	preview.texture = null
	_surface_compositor.clear()
	game_preview.set_preview_texture(null)
	frame_footprint.text = "Preview-only placement"
	if not _reader.open(path):
		status_label.text = _reader.last_error
		return
	_archive_sha256 = _reader.get_archive_fingerprint()
	if _archive_sha256.is_empty():
		_reader.close()
		status_label.text = "Could not fingerprint the opened image ARC."
		return
	if not _resolver.register_original_archive(_archive_name(), _reader.archive_path):
		var resolver_error := _resolver.last_error
		_reader.close()
		_archive_sha256 = ""
		status_label.text = "Content resolver could not register the ARC: %s" % resolver_error
		return
	_path_history.remember_source_path(_reader.archive_path)
	_path_history.apply_source_dialog(open_dialog)
	for entry in _reader.get_entries():
		var extension := str(entry.name).get_extension().to_lower()
		if extension == "mmo":
			var mmo_entry := entry.duplicate(true)
			mmo_entry["image_type"] = "MMO"
			_image_entries.append(mmo_entry)
		elif extension == "dat":
			var palette_name := "%s.PAL" % str(entry.name).get_basename()
			if not _reader.get_entry(palette_name).is_empty():
				var dat_entry := entry.duplicate(true)
				dat_entry["image_type"] = "DAT/PAL"
				dat_entry["palette_name"] = palette_name
				_image_entries.append(dat_entry)
		elif extension == "a6":
			var a6_entry := entry.duplicate(true)
			a6_entry["image_type"] = "A6 table"
			_image_entries.append(a6_entry)
		elif extension == "ax":
			var ax_entry := entry.duplicate(true)
			ax_entry["image_type"] = "AX stream"
			_image_entries.append(ax_entry)
	archive_label.text = path
	_rebuild_tree()
	status_label.text = "%d supported image/layout entries; original ARC opened read-only" % _image_entries.size()


func _on_load_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	load_overlay_dialog.popup_centered_ratio(0.75)


func _on_load_overlay_directory_selected(path: String) -> void:
	if not _can_change_loaded_overlay():
		return
	var configured := _configure_loaded_overlay(path)
	if not configured.ok:
		status_label.text = "Overlay load failed: %s" % configured.error
		return
	_refresh_after_overlay_change()
	status_label.text = "Loaded overlay read layer with %d replacement(s) for %s." % [configured.target_count, _archive_name()]


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
	_refresh_after_overlay_change()
	status_label.text = "Hot Reloaded overlay with %d replacement(s) for %s." % [configured.target_count, _archive_name()]


func _on_clear_overlay_pressed() -> void:
	if not _can_change_loaded_overlay():
		return
	if _overlay_root.is_empty():
		status_label.text = "No overlay read layer is loaded."
		return
	_resolver.clear_overlay()
	_overlay_root = ""
	_overlay_targets.clear()
	_refresh_after_overlay_change()
	status_label.text = "Cleared the overlay read layer; previews now resolve from the original ARC."


func _can_change_loaded_overlay() -> bool:
	if not _reader.is_open():
		status_label.text = "Open an image ARC before loading an overlay."
		return false
	if not _session.is_empty():
		status_label.text = "Save or remove pending image/layout replacements before changing the overlay read layer."
		return false
	if not _quantization_candidate.is_empty():
		status_label.text = "Accept or reject the DAT/PAL quantization comparison before changing the overlay read layer."
		return false
	return true


func _configure_loaded_overlay(path: String) -> Dictionary:
	var package_root := ProjectSettings.globalize_path(path).simplify_path()
	var candidate := ContentResolverScript.new()
	var archive_name := _archive_name()
	if not candidate.register_original_archive(archive_name, _reader.archive_path):
		var register_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": register_error}
	if not candidate.configure_overlay(package_root):
		var configure_error := candidate.last_error
		candidate.close()
		return {"ok": false, "error": configure_error}
	var bindings := candidate.validate_overlay_archive_bindings(archive_name)
	if not bindings.ok:
		var binding_error := str(bindings.error)
		candidate.close()
		return {"ok": false, "error": binding_error}
	if _archive_sha256.is_empty() or str(bindings.archive_sha256) != _archive_sha256:
		candidate.close()
		return {"ok": false, "error": "The open image ARC changed before overlay activation."}
	var targets: Dictionary = {}
	for untyped_record in bindings.records:
		var record: Dictionary = untyped_record
		var entry_name := str(record.target_entry)
		var descriptor: Dictionary = bindings.descriptors.get(entry_name.to_upper(), {})
		if descriptor.is_empty():
			candidate.close()
			return {"ok": false, "error": "Validated image/layout overlay binding is missing a descriptor: %s" % entry_name}
		targets[entry_name.to_upper()] = record.duplicate(true)
	var previous_resolver := _resolver
	_resolver = candidate
	_overlay_root = str(bindings.root)
	_overlay_targets = targets
	previous_resolver.close()
	return {"ok": true, "target_count": targets.size()}


func _refresh_after_overlay_change() -> void:
	_rebuild_tree()
	if not _selected_name.is_empty() and not _reader.get_entry(_selected_name).is_empty():
		_decode_selected()


func _archive_name() -> String:
	return _reader.archive_path.replace("\\", "/").get_file()


func _on_filter_changed(_value: String) -> void:
	_rebuild_tree()


func _rebuild_tree() -> void:
	entry_tree.clear()
	_entry_items.clear()
	var root := entry_tree.create_item()
	var filter := filter_edit.text.strip_edges().to_upper()
	for entry in _image_entries:
		if not filter.is_empty() and not str(entry.name).to_upper().contains(filter):
			continue
		var item := entry_tree.create_item(root)
		item.set_text(0, entry.name)
		item.set_text(1, entry.image_type)
		item.set_text(2, "%d%s" % [int(entry.size), _entry_source_suffix(str(entry.name))])
		item.set_metadata(0, entry.name)
		_entry_items[str(entry.name)] = item
	if _selected_name.is_empty():
		_update_selection_actions()
		return
	var selected_item: TreeItem = _entry_items.get(_selected_name)
	if selected_item != null:
		_restoring_tree_selection = true
		selected_item.select(0)
		_restoring_tree_selection = false
		_update_selection_actions()
		return
	_clear_hidden_selection()


func _entry_source_suffix(entry_name: String) -> String:
	if _session.has(entry_name):
		return " / Pending"
	if _entry_has_loaded_overlay(entry_name):
		return " / Overlay"
	return ""


func _entry_has_loaded_overlay(entry_name: String) -> bool:
	if _overlay_targets.has(entry_name.to_upper()):
		return true
	if entry_name.get_extension().to_lower() == "dat":
		return _overlay_targets.has(("%s.PAL" % entry_name.get_basename()).to_upper())
	return false


func _on_entry_selected() -> void:
	if _restoring_tree_selection:
		return
	var item := entry_tree.get_selected()
	if item == null:
		return
	var next_name := str(item.get_metadata(0))
	if next_name != _selected_name and not _quantization_candidate.is_empty():
		_clear_quantization_candidate(true)
	if next_name != _selected_name:
		_a6_selected_record_index = 0
	_selected_name = next_name
	_decode_selected()
	_update_selection_actions()


func _clear_hidden_selection() -> void:
	_clear_quantization_candidate(true)
	_selected_name = ""
	_clear_decoded_preview()
	_hide_a6_editor()
	_hide_ax_inspector()
	details.text = "Select a visible image or layout entry."
	status_label.text = "The filtered selection was cleared; select a visible entry before using preview or edit actions."
	_update_selection_actions()


func _update_selection_actions() -> void:
	if not is_instance_valid(import_button):
		return
	var has_visible_selection := not _selected_name.is_empty() and _entry_items.has(_selected_name)
	var extension := _selected_name.get_extension().to_lower() if has_visible_selection else ""
	import_button.disabled = not has_visible_selection or extension in ["a6", "ax"]
	remove_button.disabled = not has_visible_selection or not _session.has(_selected_name)
	export_button.disabled = (
		not has_visible_selection
		or extension in ["a6", "ax"]
		or _decoded_image == null
		or _decoded_image.is_empty()
	)


func _read_effective_entry(entry_name: String) -> Dictionary:
	var descriptor := _resolver.resolve(_archive_name(), entry_name)
	if not descriptor.ok:
		return descriptor
	var data := _resolver.read_resolved(descriptor)
	if not _resolver.last_error.is_empty():
		return {"ok": false, "error": _resolver.last_error}
	return {
		"ok": true,
		"data": data,
		"source": str(descriptor.source),
		"path": str(descriptor.get("path", "")),
	}


func _decode_selected() -> void:
	if _selected_name.get_extension().to_lower() == "a6":
		_hide_palette_editor()
		_hide_ax_inspector()
		_inspect_selected_a6()
		return
	_hide_a6_editor()
	if _selected_name.get_extension().to_lower() == "ax":
		_hide_palette_editor()
		_inspect_selected_ax()
		return
	_hide_ax_inspector()
	status_label.text = "Decoding %s…" % _selected_name
	var entry := _reader.get_entry(_selected_name)
	var decoded: Dictionary
	var palette_dat_data := PackedByteArray()
	var palette_pal_data := PackedByteArray()
	var resolved_source := "original_arc"
	if _session.has(_selected_name):
		var pending: Dictionary = _session[_selected_name]
		resolved_source = "pending session"
		if str(pending.kind) == "DAT/PAL":
			var dat_loaded := _load_descriptor(_selected_name, pending.files[_selected_name])
			var palette_name := "%s.PAL" % _selected_name.get_basename()
			var pal_loaded := _load_descriptor(palette_name, pending.files[palette_name])
			if not dat_loaded.ok or not pal_loaded.ok:
				_clear_decoded_preview()
				status_label.text = str(dat_loaded.error if not dat_loaded.ok else pal_loaded.error)
				return
			palette_dat_data = dat_loaded.data
			palette_pal_data = pal_loaded.data
			decoded = _dat_pal_codec.decode_image(dat_loaded.data, pal_loaded.data)
		else:
			var loaded := _load_pending(_selected_name)
			if not loaded.ok:
				_clear_decoded_preview()
				status_label.text = str(loaded.error)
				return
			decoded = _codec.decode_image(loaded.data)
	elif str(entry.name).get_extension().to_lower() == "mmo":
		var loaded := _read_effective_entry(_selected_name)
		if not loaded.ok:
			_clear_decoded_preview()
			status_label.text = str(loaded.error)
			return
		resolved_source = str(loaded.source)
		_hide_palette_editor()
		decoded = _codec.decode_image(loaded.data, true)
	else:
		var palette_name := "%s.PAL" % _selected_name.get_basename()
		var dat_loaded := _read_effective_entry(_selected_name)
		var pal_loaded := _read_effective_entry(palette_name)
		if not dat_loaded.ok or not pal_loaded.ok:
			_clear_decoded_preview()
			status_label.text = str(dat_loaded.error if not dat_loaded.ok else pal_loaded.error)
			return
		resolved_source = "DAT %s + PAL %s" % [dat_loaded.source, pal_loaded.source]
		palette_dat_data = dat_loaded.data
		palette_pal_data = pal_loaded.data
		decoded = _dat_pal_codec.decode_image(dat_loaded.data, pal_loaded.data)
	if not decoded.ok:
		_clear_decoded_preview()
		status_label.text = str(decoded.error)
		return
	_decoded_image = decoded.image
	var decoded_texture := ImageTexture.create_from_image(_decoded_image)
	preview.texture = decoded_texture
	_center_game_frame()
	var lines := [
		"[b]%s[/b]" % _selected_name,
		"Resolved source: %s" % resolved_source,
		"Dimensions: %d × %d" % [decoded.width, decoded.height],
	]
	if decoded.has("header_profile"):
		lines.append("MMO header profile: %s" % str(decoded.header_profile))
		lines.append("Header secondary dimensions: %d × %d" % [
			int(decoded.secondary_width), int(decoded.secondary_height),
		])
		if int(decoded.header_control) != 0 or int(decoded.header_trailer) != 0:
			lines.append("Observed special fields: control=%d · trailer=%d" % [
				int(decoded.header_control), int(decoded.header_trailer),
			])
	if _session.has(_selected_name):
		var pending: Dictionary = _session[_selected_name]
		lines.append("[color=yellow]Pending %s replacement[/color]" % pending.kind)
		if not str(pending.get("png_path", "")).is_empty():
			lines.append("PNG: %s" % str(pending.png_path).get_file())
		lines.append("Encoded bytes: %d (%+d)" % [pending.size, pending.delta])
		if str(pending.kind) == "MMO":
			lines.append("Header provenance: %s · %s" % [
				str(pending.get("header_origin", "target_template_preserved")),
				str(pending.get("compatibility", "remake_only")),
			])
		elif str(pending.kind) == "DAT/PAL":
			if str(pending.get("authoring_origin", "png_import")) == "quantization_approved":
				lines.append("Quantization approval: accepted after before/after comparison")
			var palette_edit: Dictionary = pending.get("palette_edit", {})
			if not palette_edit.is_empty():
				var previous_color: Color = palette_edit.previous_color
				var edited_color: Color = palette_edit.color
				lines.append("Palette edit: #%03d · #%s → #%s · %d referenced pixels" % [
					int(palette_edit.index),
					previous_color.to_html(false).to_upper(),
					edited_color.to_html(false).to_upper(),
					int(palette_edit.use_count),
				])
			var diagnostics: Dictionary = pending.get("quantization_diagnostics", {})
			if not diagnostics.is_empty():
				lines.append("Imported colors: %d source → %d palette (limit %d)" % [
					int(diagnostics.get("source_color_count", 0)),
					int(diagnostics.get("palette_color_count", 0)),
					int(diagnostics.get("palette_limit", 0)),
				])
				lines.append("Quantization: %d changed pixels · RGB MAE %.3f · max channel %d" % [
					int(diagnostics.get("changed_pixel_count", 0)),
					float(diagnostics.get("mean_absolute_rgb_error", 0.0)),
					int(diagnostics.get("maximum_channel_error", 0)),
				])
	if decoded.has("compressed_bytes"):
		var padding_note := "complete"
		if int(decoded.padded_bytes) > 0:
			padding_note = "zero-padded %d bytes for preview" % int(decoded.padded_bytes)
		lines.append("Compressed entry payload: %d bytes" % decoded.compressed_bytes)
		lines.append("Decoded RGB source: %d bytes" % decoded.decoded_bytes)
		lines.append("Decode status: %s" % padding_note)
	else:
		_show_palette_editor(palette_dat_data, palette_pal_data)
		lines.append("Palette: %s.PAL" % _selected_name.get_basename())
		lines.append("Index-zero alpha: %s" % decoded.transparent_index_zero)
		lines.append("Palette use: %d indices (%d opaque) · %d unused" % [
			int(decoded.used_palette_entries),
			int(decoded.used_opaque_palette_entries),
			int(decoded.unused_palette_entries),
		])
		if bool(decoded.transparent_index_zero):
			lines.append("Index zero: %d transparent pixels · reserved for alpha" % int(decoded.index_zero_pixel_count))
	details.text = "\n".join(lines)
	status_label.text = "%s decoded from %s" % [_selected_name, resolved_source]
	_update_selection_actions()


func _show_palette_editor(dat_data: PackedByteArray, pal_data: PackedByteArray) -> void:
	var inspected := _dat_pal_codec.inspect_palette(dat_data, pal_data)
	if not inspected.ok:
		_hide_palette_editor()
		status_label.text = "Palette inspection failed: %s" % str(inspected.error)
		return
	_palette_document = inspected
	_palette_dat_data = dat_data.duplicate()
	_palette_pal_data = pal_data.duplicate()
	_updating_palette_controls = true
	palette_entry_select.clear()
	for entry in inspected.entries:
		var suffix := "%d pixels" % int(entry.use_count)
		if bool(entry.reserved_transparent):
			suffix += " · transparent/reserved"
		elif not bool(entry.used):
			suffix += " · unused"
		palette_entry_select.add_item("#%03d · #%02X%02X%02X · %s" % [
			int(entry.index), int(entry.red), int(entry.green), int(entry.blue), suffix,
		])
	palette_entry_select.select(0)
	_updating_palette_controls = false
	palette_editor.visible = true
	_on_palette_entry_selected(0)


func _hide_palette_editor() -> void:
	_palette_document.clear()
	_palette_dat_data.clear()
	_palette_pal_data.clear()
	if is_instance_valid(palette_editor):
		palette_editor.visible = false
		palette_entry_select.clear()
		stage_palette.disabled = true
		palette_summary.text = "Select a DAT/PAL image"


func _on_palette_entry_selected(option_index: int) -> void:
	if _updating_palette_controls or _palette_document.is_empty():
		return
	if option_index < 0 or option_index >= _palette_document.entries.size():
		stage_palette.disabled = true
		palette_summary.text = "Palette selection is outside the decoded table."
		return
	var entry: Dictionary = _palette_document.entries[option_index]
	_updating_palette_controls = true
	palette_color.color = entry.color
	_updating_palette_controls = false
	stage_palette.disabled = bool(entry.reserved_transparent)
	palette_summary.text = "%d pixel(s)%s" % [
		int(entry.use_count),
		" · index zero is reserved for alpha" if bool(entry.reserved_transparent) else "",
	]


func _on_stage_palette_pressed() -> void:
	if _selected_name.get_extension().to_lower() != "dat" or _palette_document.is_empty():
		status_label.text = "Select a decoded DAT/PAL palette entry first."
		return
	var selected_index := palette_entry_select.selected
	if selected_index < 0 or selected_index >= _palette_document.entries.size():
		status_label.text = "Palette edit rejected: selected entry is outside the decoded table."
		return
	var selected_entry: Dictionary = _palette_document.entries[selected_index]
	var replaced := _dat_pal_codec.replace_palette_entry(
		_palette_pal_data,
		selected_index,
		palette_color.color,
		bool(selected_entry.reserved_transparent)
	)
	if not replaced.ok:
		status_label.text = "Palette edit rejected: %s" % str(replaced.error)
		return
	if not bool(replaced.changed):
		status_label.text = "Palette entry #%03d is unchanged." % selected_index
		return
	var verified := _dat_pal_codec.decode_image(_palette_dat_data, replaced.pal_data)
	if not verified.ok:
		status_label.text = "Palette edit rejected: reopened DAT/PAL pair failed: %s" % str(verified.error)
		return
	var dat_entry := _reader.get_entry(_selected_name)
	var palette_name := "%s.PAL" % _selected_name.get_basename()
	var pal_entry := _reader.get_entry(palette_name)
	if dat_entry.is_empty() or pal_entry.is_empty():
		status_label.text = "Palette edit rejected: original DAT/PAL pair is incomplete."
		return
	var staged_dat := _stage_encoded_data(int(dat_entry.index), "DAT", _palette_dat_data)
	if not staged_dat.ok:
		status_label.text = "Palette edit staging failed: %s" % str(staged_dat.error)
		return
	var staged_pal := _stage_encoded_data(int(pal_entry.index), "PAL", replaced.pal_data)
	if not staged_pal.ok:
		_remove_session_file(str(staged_dat.path))
		status_label.text = "Palette edit staging failed: %s" % str(staged_pal.error)
		return
	if _session.has(_selected_name):
		_remove_pending_files(_session[_selected_name])
	var total_size: int = _palette_dat_data.size() + replaced.pal_data.size()
	var original_size: int = int(dat_entry.size) + int(pal_entry.size)
	_session[_selected_name] = {
		"kind": "DAT/PAL",
		"authoring_origin": "palette_edit",
		"files": {
			_selected_name: {"path": staged_dat.path, "sha256": staged_dat.sha256, "size": _palette_dat_data.size()},
			palette_name: {"path": staged_pal.path, "sha256": staged_pal.sha256, "size": replaced.pal_data.size()},
		},
		"size": total_size,
		"original_size": original_size,
		"delta": total_size - original_size,
		"png_path": "",
		"palette_edit": {
			"schema": str(replaced.schema),
			"index": selected_index,
			"use_count": int(selected_entry.use_count),
			"previous_color": replaced.previous_color,
			"color": replaced.color,
		},
		"compatibility": "remake_only",
	}
	_refresh_session_marks()
	_decode_selected()
	status_label.text = "Palette entry #%03d staged for %s/%s; %d image replacement(s) pending." % [
		selected_index, _selected_name, palette_name, _session.size(),
	]


func _inspect_selected_a6() -> void:
	_clear_decoded_preview()
	var data: PackedByteArray
	var resolved_source := "original_arc"
	if _session.has(_selected_name):
		resolved_source = "pending session"
		var loaded := _load_pending(_selected_name)
		if not loaded.ok:
			_hide_a6_editor()
			details.text = "[b]%s[/b]\nPending A6 validation failed: %s" % [_selected_name, loaded.error]
			status_label.text = "%s pending payload rejected: %s" % [_selected_name, loaded.error]
			return
		data = loaded.data
	else:
		var loaded := _read_effective_entry(_selected_name)
		if not loaded.ok:
			_hide_a6_editor()
			details.text = "[b]%s[/b]\nA6 resolution failed: %s" % [_selected_name, loaded.error]
			status_label.text = "%s resolution failed: %s" % [_selected_name, loaded.error]
			return
		data = loaded.data
		resolved_source = str(loaded.source)
	var inspected := _a6_layout.inspect(data)
	if not inspected.ok:
		_hide_a6_editor()
		details.text = "[b]%s[/b]\nA6 structural validation failed: %s" % [_selected_name, inspected.error]
		status_label.text = "%s rejected: %s" % [_selected_name, inspected.error]
		return
	_a6_document = inspected
	_a6_data = data
	_populate_a6_editor()
	preview_tabs.current_tab = 1
	var lines := [
		"[b]%s[/b]" % _selected_name,
		"A6 input-region table",
		"Resolved source: %s" % resolved_source,
		"Schema: %s" % inspected.schema,
		"Record count: %d" % int(inspected.record_count),
		"Record width: %d bytes (ID, left, top, right, bottom as little-endian u16)" % int(inspected.record_bytes),
		"Terminal word: 0x%04X" % int(inspected.terminal_word),
		"Edges: inclusive · first matching record wins",
		"Duplicate IDs: %d · inverted rectangles: %d" % [
			int(inspected.duplicate_id_count),
			int(inspected.invalid_rectangle_count),
		],
		"First-match overlaps: %d pairs · %d partial · %d unreachable" % [
			int(inspected.overlap_pair_count),
			int(inspected.partially_occluded_count),
			int(inspected.unreachable_record_count),
		],
		"",
		"Original-EXE hit testing confirms the input rectangles. This table contains no decoded pixels. Field and ordered-table edits below are encoded and reopened before staging.",
	]
	if _session.has(_selected_name):
		lines.insert(1, "[color=yellow]Pending verified A6 replacement[/color]")
	var preview_count := mini(12, int(inspected.record_count))
	if preview_count > 0:
		lines.append("")
		lines.append("[font_size=12][b]Offset   ID     Inclusive rectangle[/b]")
		for record_index in range(preview_count):
			var record: Dictionary = inspected.records[record_index]
			var reachability := ""
			if bool(record.fully_unreachable_by_first_match):
				reachability = "  [UNREACHABLE]"
			elif bool(record.partially_occluded_by_first_match):
				reachability = "  [partial: %d visible]" % int(record.visible_pixel_count)
			lines.append(
				"0x%04X  %5d  (%d, %d) .. (%d, %d)%s" % [
					int(record.offset), int(record.id), int(record.left), int(record.top),
					int(record.right), int(record.bottom), reachability,
				]
			)
		if preview_count < int(inspected.record_count):
			lines.append("… %d more record(s)" % (int(inspected.record_count) - preview_count))
		lines.append("[/font_size]")
	details.text = "\n".join(lines)
	frame_footprint.text = "A6 input regions have no decoded pixel frame"
	status_label.text = "%s input regions ready from %s; %d records%s" % [
		_selected_name,
		resolved_source,
		int(inspected.record_count),
		"; pending replacement loaded" if _session.has(_selected_name) else "",
	]


func _populate_a6_editor() -> void:
	_updating_a6_controls = true
	a6_record_select.clear()
	var records: Array = _a6_document.get("records", [])
	for record_index in range(records.size()):
		var record: Dictionary = records[record_index]
		var reachability := ""
		if bool(record.fully_unreachable_by_first_match):
			reachability = " · unreachable"
		elif bool(record.partially_occluded_by_first_match):
			reachability = " · partial"
		a6_record_select.add_item("#%d · ID %d · (%d,%d)..(%d,%d)%s" % [
			record_index,
			int(record.id),
			int(record.left),
			int(record.top),
			int(record.right),
			int(record.bottom),
			reachability,
		])
	var has_records := not records.is_empty()
	a6_record_select.disabled = not has_records
	stage_a6.disabled = not has_records
	for control in [a6_id, a6_left, a6_top, a6_right, a6_bottom]:
		(control as SpinBox).editable = has_records
	if has_records:
		_a6_selected_record_index = clampi(_a6_selected_record_index, 0, records.size() - 1)
		a6_record_select.select(_a6_selected_record_index)
		_set_a6_controls(records[_a6_selected_record_index])
	else:
		_a6_selected_record_index = -1
		_set_a6_controls({"id": 0, "left": 0, "top": 0, "right": 0, "bottom": 0})
	_update_a6_operation_controls()
	a6_editor.visible = true
	if is_instance_valid(_a6_region_overlay):
		_a6_region_overlay.set_regions(records, _a6_selected_record_index)
	_updating_a6_controls = false


func _set_a6_controls(record: Dictionary) -> void:
	a6_id.value = int(record.id)
	a6_left.value = int(record.left)
	a6_top.value = int(record.top)
	a6_right.value = int(record.right)
	a6_bottom.value = int(record.bottom)


func _hide_a6_editor() -> void:
	_a6_document = {}
	_a6_data.clear()
	if is_instance_valid(a6_editor):
		a6_editor.visible = false
		a6_diagnostics.text = "No A6 diagnostics"
	if is_instance_valid(_a6_region_overlay):
		_a6_region_overlay.clear_regions()


func _on_a6_record_selected(record_index: int) -> void:
	if _updating_a6_controls:
		return
	var records: Array = _a6_document.get("records", [])
	if record_index < 0 or record_index >= records.size():
		return
	_a6_selected_record_index = record_index
	_updating_a6_controls = true
	_set_a6_controls(records[record_index])
	if is_instance_valid(_a6_region_overlay):
		_a6_region_overlay.set_selected_index(record_index)
	_updating_a6_controls = false
	_update_a6_operation_controls()
	_update_a6_pointer_status(Vector2(-1, -1), record_index)


func _update_a6_operation_controls() -> void:
	if not is_instance_valid(a6_add):
		return
	var records: Array = _a6_document.get("records", [])
	var valid_selection := _a6_selected_record_index >= 0 and _a6_selected_record_index < records.size()
	a6_add.disabled = _a6_document.is_empty()
	a6_duplicate.disabled = not valid_selection
	a6_remove.disabled = not valid_selection
	a6_move_up.disabled = not valid_selection or _a6_selected_record_index == 0
	a6_move_down.disabled = not valid_selection or _a6_selected_record_index >= records.size() - 1
	if not valid_selection:
		a6_diagnostics.text = "%d records · %d overlaps · %d partial · %d unreachable" % [
			records.size(),
			int(_a6_document.get("overlap_pair_count", 0)),
			int(_a6_document.get("partially_occluded_count", 0)),
			int(_a6_document.get("unreachable_record_count", 0)),
		]
		return
	var record: Dictionary = records[_a6_selected_record_index]
	var selected_status := "%d visible / %d pixels" % [int(record.visible_pixel_count), int(record.pixel_area)]
	if bool(record.fully_unreachable_by_first_match):
		selected_status = "UNREACHABLE · 0 / %d pixels visible" % int(record.pixel_area)
	elif bool(record.partially_occluded_by_first_match):
		selected_status = "PARTIAL · %s" % selected_status
	a6_diagnostics.text = "%d overlaps · %d partial · %d unreachable · selected %s" % [
		int(_a6_document.get("overlap_pair_count", 0)),
		int(_a6_document.get("partially_occluded_count", 0)),
		int(_a6_document.get("unreachable_record_count", 0)),
		selected_status,
	]


func _on_game_preview_pointer_moved(logical_position: Vector2) -> void:
	if _a6_document.is_empty() or _a6_data.is_empty():
		return
	var hit := _a6_layout.hit_test(_a6_data, floori(logical_position.x), floori(logical_position.y))
	var record_index := int(hit.get("record_index", -1)) if hit.get("ok", false) and hit.get("found", false) else -1
	if is_instance_valid(_a6_region_overlay):
		_a6_region_overlay.set_hovered_index(record_index)
	_update_a6_pointer_status(logical_position, record_index)


func _on_game_preview_pointer_pressed(logical_position: Vector2) -> void:
	if _a6_document.is_empty() or _a6_data.is_empty():
		return
	var hit := _a6_layout.hit_test(_a6_data, floori(logical_position.x), floori(logical_position.y))
	if not hit.get("ok", false) or not hit.get("found", false):
		status_label.text = "No A6 input region contains (%d, %d)." % [floori(logical_position.x), floori(logical_position.y)]
		return
	var record_index := int(hit.record_index)
	a6_record_select.select(record_index)
	_on_a6_record_selected(record_index)
	status_label.text = "Selected first matching A6 record #%d (ID %d) at (%d, %d)." % [
		record_index,
		int(hit.record_id),
		floori(logical_position.x),
		floori(logical_position.y),
	]


func _update_a6_pointer_status(logical_position: Vector2, record_index: int) -> void:
	if record_index < 0:
		if logical_position.x >= 0.0:
			frame_footprint.text = "A6 input regions · (%d, %d): no match" % [floori(logical_position.x), floori(logical_position.y)]
		return
	var records: Array = _a6_document.get("records", [])
	if record_index >= records.size():
		return
	var record: Dictionary = records[record_index]
	var prefix := "A6 selected" if logical_position.x < 0.0 else "A6 first match at (%d, %d)" % [floori(logical_position.x), floori(logical_position.y)]
	frame_footprint.text = "%s · #%d ID %d · (%d,%d)..(%d,%d)" % [
		prefix,
		record_index,
		int(record.id),
		int(record.left),
		int(record.top),
		int(record.right),
		int(record.bottom),
	]


func _on_stage_a6_record_pressed() -> void:
	if _selected_name.get_extension().to_lower() != "a6" or _a6_document.is_empty():
		status_label.text = "Select and inspect an A6 entry first."
		return
	var records: Array = _a6_document.get("records", []).duplicate(true)
	if _a6_selected_record_index < 0 or _a6_selected_record_index >= records.size():
		status_label.text = "Select an existing A6 record first."
		return
	var edited: Dictionary = records[_a6_selected_record_index]
	edited["id"] = int(a6_id.value)
	edited["left"] = int(a6_left.value)
	edited["top"] = int(a6_top.value)
	edited["right"] = int(a6_right.value)
	edited["bottom"] = int(a6_bottom.value)
	var encoded := _a6_layout.encode_records(records)
	if not encoded.ok:
		status_label.text = "A6 edit rejected: %s" % encoded.error
		return
	_stage_a6_table(encoded.data, _a6_selected_record_index, "field_edit", "record #%d" % _a6_selected_record_index)


func _on_add_a6_record_pressed() -> void:
	if _selected_name.get_extension().to_lower() != "a6" or _a6_document.is_empty():
		status_label.text = "Select and inspect an A6 entry first."
		return
	var records: Array = _a6_document.get("records", [])
	var insert_index := _a6_selected_record_index + 1 if _a6_selected_record_index >= 0 else 0
	var new_id := _next_available_a6_id(records)
	if new_id < 0:
		status_label.text = "A6 add rejected: every non-terminal u16 ID is already present."
		return
	var inserted := _a6_layout.insert_record(_a6_data, insert_index, {
		"id": new_id,
		"left": 0,
		"top": 0,
		"right": 0,
		"bottom": 0,
	})
	if not inserted.ok:
		status_label.text = "A6 add rejected: %s" % str(inserted.error)
		return
	_stage_a6_table(inserted.data, int(inserted.selected_index), "insert", "new record #%d" % int(inserted.selected_index))


func _on_duplicate_a6_record_pressed() -> void:
	var duplicated := _a6_layout.duplicate_record(_a6_data, _a6_selected_record_index)
	if not duplicated.ok:
		status_label.text = "A6 duplicate rejected: %s" % str(duplicated.error)
		return
	_stage_a6_table(duplicated.data, int(duplicated.selected_index), "duplicate", "duplicated record #%d" % int(duplicated.selected_index))


func _on_remove_a6_record_pressed() -> void:
	var removed := _a6_layout.remove_record(_a6_data, _a6_selected_record_index)
	if not removed.ok:
		status_label.text = "A6 remove rejected: %s" % str(removed.error)
		return
	_stage_a6_table(removed.data, int(removed.selected_index), "remove", "removed record")


func _on_move_a6_record_up_pressed() -> void:
	_move_a6_record_to(_a6_selected_record_index - 1)


func _on_move_a6_record_down_pressed() -> void:
	_move_a6_record_to(_a6_selected_record_index + 1)


func _move_a6_record_to(destination_index: int) -> void:
	var moved := _a6_layout.move_record(_a6_data, _a6_selected_record_index, destination_index)
	if not moved.ok:
		status_label.text = "A6 move rejected: %s" % str(moved.error)
		return
	_stage_a6_table(moved.data, int(moved.selected_index), "move", "moved record to #%d" % int(moved.selected_index))


func _next_available_a6_id(records: Array) -> int:
	var used: Dictionary = {}
	for untyped_record in records:
		used[int((untyped_record as Dictionary).id)] = true
	for candidate in range(0xFFFF):
		if not used.has(candidate):
			return candidate
	return -1


func _stage_a6_table(data: PackedByteArray, selected_index: int, operation: String, status_action: String) -> void:
	var verified := _a6_layout.inspect(data)
	if not verified.ok:
		status_label.text = "A6 %s rejected: encoded table did not reopen: %s" % [operation, str(verified.error)]
		return
	if selected_index < -1 or selected_index >= int(verified.record_count):
		status_label.text = "A6 %s rejected: reopened selection is outside the table." % operation
		return
	var entry := _reader.get_entry(_selected_name)
	if entry.is_empty():
		status_label.text = "A6 %s rejected: selected source entry is unavailable." % operation
		return
	var staged := _stage_encoded_data(int(entry.index), "A6", data)
	if not staged.ok:
		status_label.text = "A6 staging failed: %s" % staged.error
		return
	if _session.has(_selected_name):
		_remove_pending_files(_session[_selected_name])
	_session[_selected_name] = {
		"kind": "A6",
		"path": staged.path,
		"sha256": staged.sha256,
		"size": data.size(),
		"original_size": int(entry.size),
		"delta": data.size() - int(entry.size),
		"edited_record_index": selected_index,
		"edit_operation": operation,
		"compatibility": "original_engine_compatible",
	}
	_a6_selected_record_index = selected_index
	_refresh_session_marks()
	_inspect_selected_a6()
	status_label.text = "%s %s staged and reopened; %d records, %d overlap pairs, %d replacement(s) pending." % [
		_selected_name,
		status_action,
		int(verified.record_count),
		int(verified.overlap_pair_count),
		_session.size(),
	]


func _inspect_selected_ax() -> void:
	_clear_decoded_preview()
	var data: PackedByteArray
	var resolved_source := "original_arc"
	if _session.has(_selected_name):
		resolved_source = "pending session"
		var pending_loaded := _load_pending(_selected_name)
		if not pending_loaded.ok:
			_hide_ax_inspector()
			details.text = "[b]%s[/b]\nPending AX validation failed: %s" % [_selected_name, pending_loaded.error]
			status_label.text = "%s pending payload rejected: %s" % [_selected_name, pending_loaded.error]
			return
		data = pending_loaded.data
	else:
		var loaded := _read_effective_entry(_selected_name)
		if not loaded.ok:
			_hide_ax_inspector()
			details.text = "[b]%s[/b]\nAX resolution failed: %s" % [_selected_name, loaded.error]
			status_label.text = "%s resolution failed: %s" % [_selected_name, loaded.error]
			return
		data = loaded.data
		resolved_source = str(loaded.source)
	var inspected := _ax_dword_stream.inspect(data)
	if not inspected.ok:
		_hide_ax_inspector()
		details.text = "[b]%s[/b]\nAX structural validation failed: %s" % [_selected_name, inspected.error]
		status_label.text = "%s rejected: %s" % [_selected_name, inspected.error]
		return
	var animation := _ax_animation.inspect(data)
	if not animation.ok:
		_hide_ax_inspector()
		details.text = "[b]%s[/b]\nAX animation validation failed: %s" % [_selected_name, animation.error]
		status_label.text = "%s rejected: %s" % [_selected_name, animation.error]
		return
	_ax_document = animation
	_ax_source_data = data
	_ax_edited_document = animation.duplicate(true)
	_ax_edit_count = 0
	_ax_changed_cells.clear()
	_ax_changed_records.clear()
	_ax_selected_row = -1
	_ax_selected_column = -1
	_ax_selected_command_index = -1
	_ax_selected_record_index = -1
	_populate_ax_inspector()
	preview_tabs.current_tab = 1
	var binding: Dictionary = animation.binding_table
	var type_keys: Array = binding.target_first_byte_counts.keys()
	type_keys.sort()
	var type_parts: Array[String] = []
	for type_key in type_keys:
		type_parts.append("%02X:%d" % [int(type_key), int(binding.target_first_byte_counts[type_key])])
	var record_type_keys: Array = animation.shared_type_counts.keys()
	record_type_keys.sort()
	var record_type_parts: Array[String] = []
	for type_key in record_type_keys:
		record_type_parts.append("%d:%d" % [int(type_key), int(animation.shared_type_counts[type_key])])
	var opcode_keys: Array = animation.opcode_counts.keys()
	opcode_keys.sort()
	var opcode_parts: Array[String] = []
	for opcode_key in opcode_keys:
		opcode_parts.append("%02X:%d" % [int(opcode_key), int(animation.opcode_counts[opcode_key])])
	var lines := [
		"[b]%s[/b]" % _selected_name,
		"Read-only native AX binding table",
		"Resolved source: %s" % resolved_source,
		"Schema: %s" % binding.schema,
		"Shape: %d x %d = %d entry-relative offsets (%d bytes / 0x%X)" % [
			int(binding.row_count), int(binding.column_count), int(binding.entry_count),
			int(binding.table_bytes), int(binding.table_bytes),
		],
		"Target range: 0x%X .. 0x%X" % [int(binding.minimum_target_offset), int(binding.maximum_target_offset)],
		"Target offsets: %s / %d unique" % [
			"strictly increasing" if binding.strictly_increasing else "not strictly increasing",
			int(binding.unique_target_count),
		],
		"Non-FF target cells: %d / %d" % [int(binding.non_ff_entry_count), int(binding.entry_count)],
		"Cell start-opcode counts: %s" % ", ".join(type_parts),
		"",
		"Native AX animation stream",
		"Schema: %s" % animation.schema,
		"Shared draw records: %d x 0x%X bytes (dispatch types %s)" % [
			int(animation.shared_record_count), int(animation.shared_record_bytes), ", ".join(record_type_parts),
		],
		"Destination rectangles within 640x400: %d / %d" % [
			int(animation.logical_destination_rect_count), int(animation.shared_record_count),
		],
		"Source rectangles within native surface 8 (2688x864): %d / %d" % [
			int(animation.source_rect_count), int(animation.shared_record_count),
		],
		"Cell streams: %d; commands: %d; shared-record dispatches: %d" % [
			int(animation.stream_count), int(animation.command_count), int(animation.shared_record_dispatch_count),
		],
		"Opcode counts: %s" % ", ".join(opcode_parts),
		"Native copy: 3-byte pixels with RGB key 0x%06X" % int(animation.transparent_rgb),
		"",
		"The EXE confirms surface 8 (2688x864) -> surface 0 (640x400) chroma-key copies. AX stores no pixels. Audited EVENTB02/EVENTB14 routes load their AN MMO into surface 8 before AX; this detached inspector has no selected MES producer and native animation timing remains unresolved.",
		"",
		"Neutral aligned-dword boundary",
		"Schema: %s" % inspected.schema,
		"Token count: %d" % int(inspected.token_count),
		"Terminator offset: 0x%X" % int(inspected.terminator_offset),
		"0xFF suffix bytes: %d" % int(inspected.padding_bytes),
		"",
		_ax_writer_round_trip_line(animation, data),
	]
	if _session.has(_selected_name):
		lines.insert(1, "[color=yellow]Pending verified AX replacement[/color]")
	var preview_count := mini(16, int(binding.non_ff_entry_count))
	if preview_count > 0:
		lines.append("")
		lines.append("[font_size=12][b]First %d non-FF target cell(s)[/b]" % preview_count)
		lines.append("Cell       Table     Target    Start opcode")
		for entry_index in range(preview_count):
			var binding_entry: Dictionary = binding.non_ff_entries[entry_index]
			lines.append("(%d,%d)     0x%04X    0x%04X    0x%02X" % [
				int(binding_entry.row), int(binding_entry.column), int(binding_entry.table_offset),
				int(binding_entry.target_offset), int(binding_entry.target_first_byte),
			])
		lines.append("[/font_size]")
	_ax_details_base_text = "\n".join(lines)
	_update_ax_details_pending_line()
	frame_footprint.text = "AX drives native surface 8 -> 0; it contains no standalone pixel frame"
	status_label.text = "%s inspected from %s; %d table cells, %d non-FF targets%s" % [
		_selected_name, resolved_source, int(binding.entry_count), int(binding.non_ff_entry_count),
		"; pending replacement loaded" if _session.has(_selected_name) else "",
	]


func _ax_writer_round_trip_line(animation: Dictionary, data: PackedByteArray) -> String:
	var serialized := _ax_writer.serialize(animation)
	if serialized.ok and serialized.data == data:
		return "Writer round trip: byte-identical (%d bytes)" % int(serialized.byte_count)
	return "Writer round trip: DIFFERENT - AX stays read-only"


func _populate_ax_inspector() -> void:
	ax_cell_select.clear()
	_ax_cell_stream_indices.clear()
	var document := _ax_current_document()
	var binding: Dictionary = document.get("binding_table", {})
	var streams: Array = document.get("streams", [])
	for untyped_entry in binding.get("non_ff_entries", []):
		var entry: Dictionary = untyped_entry
		var stream_index := int(entry.index)
		if stream_index < 0 or stream_index >= streams.size():
			continue
		var stream: Dictionary = streams[stream_index]
		var dispatch_count := _ax_stream_dispatch_indices(stream).size()
		_ax_cell_stream_indices.append(stream_index)
		ax_cell_select.add_item("(%d,%d) · target 0x%04X · %d dispatch ref%s" % [
			int(entry.row),
			int(entry.column),
			int(entry.target_offset),
			dispatch_count,
			"" if dispatch_count == 1 else "s",
		])
	var has_cells := not _ax_cell_stream_indices.is_empty()
	ax_cell_select.disabled = not has_cells
	ax_inspector.visible = true
	ax_editor.visible = true
	if not has_cells:
		ax_cell_summary.text = "No non-FF cell stream is available"
		_ax_destination_overlay.clear_records()
		ax_command_select.clear()
		ax_command_select.disabled = true
		ax_record_select.clear()
		ax_record_select.disabled = true
		return
	var selected_option := 0
	var preferred_found := false
	if _ax_selected_row >= 0:
		for option_index in range(_ax_cell_stream_indices.size()):
			var preferred_candidate: Dictionary = streams[_ax_cell_stream_indices[option_index]]
			if (
				int(preferred_candidate.get("row", -1)) == _ax_selected_row
				and int(preferred_candidate.get("column", -1)) == _ax_selected_column
			):
				selected_option = option_index
				preferred_found = true
				break
	if not preferred_found:
		for option_index in range(_ax_cell_stream_indices.size()):
			var stream: Dictionary = streams[_ax_cell_stream_indices[option_index]]
			if not _ax_stream_dispatch_indices(stream).is_empty():
				selected_option = option_index
				break
	ax_cell_select.select(selected_option)
	_show_ax_cell(selected_option)


func _on_ax_cell_selected(option_index: int) -> void:
	_show_ax_cell(option_index)


func _on_ax_play_pause_pressed() -> void:
	if _ax_tool_timeline.is_empty():
		return
	if _ax_tool_playing:
		_set_ax_tool_playing(false)
		status_label.text = "%s AX tool preview paused" % _selected_name
		return
	if bool(_ax_tool_scheduler.snapshot().get("finished", false)):
		_restart_ax_tool_preview(false)
	_set_ax_tool_playing(true)
	status_label.text = "%s AX tool preview playing on the shared 60 Hz tool clock; native cadence unconfirmed" % _selected_name


func _on_ax_restart_pressed() -> void:
	_restart_ax_tool_preview(true)


func _show_ax_cell(option_index: int) -> void:
	if option_index < 0 or option_index >= _ax_cell_stream_indices.size():
		return
	var stream_index := _ax_cell_stream_indices[option_index]
	var document := _ax_current_document()
	var streams: Array = document.get("streams", [])
	if stream_index < 0 or stream_index >= streams.size():
		return
	var stream: Dictionary = streams[stream_index]
	_ax_selected_row = int(stream.row)
	_ax_selected_column = int(stream.column)
	var dispatch_indices := _ax_stream_dispatch_indices(stream)
	var drawable_records: Array = []
	_ax_drawable_records_by_index.clear()
	var no_op_count := 0
	var playback_plan := _ax_playback_planner.compile(
		document,
		int(stream.row),
		int(stream.column),
		Vector2i(int(document.source_surface_width), int(document.source_surface_height))
	)
	_ax_tool_playback_plan = playback_plan.duplicate(true) if playback_plan.get("ok", false) else {}
	if not _ax_tool_playback_plan.is_empty():
		for untyped_frame in _ax_tool_playback_plan.get("frames", []):
			var frame: Dictionary = untyped_frame
			if bool(frame.get("drawable", false)):
				drawable_records.append(frame)
				_ax_drawable_records_by_index[int(frame.playback_frame_index)] = frame
			else:
				no_op_count += 1
	_ax_structural_records = drawable_records.duplicate(true)
	_ax_destination_overlay.set_dispatch_records(_ax_structural_records)
	_ax_showing_structural_overview = true
	var timeline: Dictionary = (
		_ax_tool_playback_plan.get("timeline", {})
		if not _ax_tool_playback_plan.is_empty()
		else {"ok": false, "error": playback_plan.get("error", "playback plan unavailable")}
	)
	_ax_tool_timeline = timeline.duplicate(true) if timeline.get("ok", false) else {}
	_ax_tool_scheduler.clear()
	_set_ax_tool_playing(false)
	var schedule_status := "timeline unavailable: %s" % str(timeline.get("error", "unsupported control stream"))
	if not _ax_tool_timeline.is_empty():
		var configured: Dictionary = _ax_tool_scheduler.configure(_ax_tool_timeline, AX_TOOL_TICK_SECONDS)
		if configured.get("ok", false):
			schedule_status = "%d tool ticks · %d dispatches · %s" % [
				int(_ax_tool_timeline.tool_ticks_per_cycle),
				(_ax_tool_timeline.dispatch_events as Array).size(),
				"loops" if bool(_ax_tool_timeline.reset_at_end) else "terminal",
			]
			ax_play_pause.disabled = false
			ax_restart.disabled = false
			_update_ax_clock_summary(configured.get("snapshot", {}), "structural overview")
		else:
			_ax_tool_timeline.clear()
			schedule_status = "timeline rejected: %s" % str(configured.get("error", "unknown scheduler error"))
	if _ax_tool_timeline.is_empty():
		ax_play_pause.disabled = true
		ax_restart.disabled = true
		ax_clock_summary.text = "Tool clock unavailable · native cadence unconfirmed"
	ax_cell_summary.text = "(%d,%d) · %d stored commands · %d dispatch refs · %d confirmed destination%s%s" % [
		int(stream.row),
		int(stream.column),
		(stream.commands as Array).size(),
		dispatch_indices.size(),
		drawable_records.size(),
		"" if drawable_records.size() == 1 else "s",
		" · %d no-op/unbounded" % no_op_count if no_op_count > 0 else "",
	]
	frame_footprint.text = "AX structural cell (%d,%d) · %s · shared 60 Hz tool preview; native cadence unconfirmed" % [
		int(stream.row), int(stream.column),
		schedule_status,
	]
	status_label.text = "%s cell (%d,%d): %d confirmed destination rectangle reference(s); %s" % [
		_selected_name, int(stream.row), int(stream.column), drawable_records.size(), schedule_status,
	]
	_populate_ax_command_select(stream)
	_populate_ax_record_select(document)
	_update_ax_diagnostics()


func _restart_ax_tool_preview(show_status: bool) -> void:
	if _ax_tool_timeline.is_empty():
		return
	var configured: Dictionary = _ax_tool_scheduler.configure(_ax_tool_timeline, AX_TOOL_TICK_SECONDS)
	if not configured.get("ok", false):
		_ax_tool_timeline.clear()
		_set_ax_tool_playing(false)
		ax_play_pause.disabled = true
		ax_restart.disabled = true
		ax_clock_summary.text = "Tool clock rejected · native cadence unconfirmed"
		status_label.text = "%s AX tool clock rejected: %s" % [_selected_name, configured.get("error", "unknown error")]
		return
	_set_ax_tool_playing(false)
	_ax_destination_overlay.set_dispatch_records(_ax_structural_records)
	_ax_showing_structural_overview = true
	_update_ax_clock_summary(configured.get("snapshot", {}), "structural overview")
	if show_status:
		status_label.text = "%s AX tool preview restarted at tick 0; structural overview shown until the first dispatch" % _selected_name


func _advance_ax_tool_ticks(count: int) -> void:
	if count <= 0 or _ax_tool_timeline.is_empty():
		return
	_apply_ax_scheduler_result(_ax_tool_scheduler.advance_ticks(count))


func _apply_ax_scheduler_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		_set_ax_tool_playing(false)
		status_label.text = "%s AX tool clock stopped: %s" % [_selected_name, result.get("error", "unknown error")]
		return
	var events: Array = result.get("events", [])
	for event in events:
		var shared_record_index := int(event.get("shared_record_index", -1))
		if _ax_drawable_records_by_index.has(shared_record_index):
			_ax_destination_overlay.set_dispatch_records([_ax_drawable_records_by_index[shared_record_index]])
		else:
			_ax_destination_overlay.clear_records()
	if not events.is_empty():
		_ax_showing_structural_overview = false
	var snapshot: Dictionary = result.get("snapshot", {})
	_update_ax_clock_summary(snapshot, "structural overview" if _ax_showing_structural_overview else "current dispatch")
	if bool(snapshot.get("finished", false)):
		_set_ax_tool_playing(false)


func _update_ax_clock_summary(snapshot: Dictionary, display_mode: String) -> void:
	ax_clock_summary.text = "Tick %d / %d · frame %d · %s · shared tool clock (native cadence unconfirmed)" % [
		int(snapshot.get("current_tick", 0)),
		int(snapshot.get("cycle_ticks", 0)),
		int(snapshot.get("current_shared_record_index", -1)),
		display_mode,
	]


func _set_ax_tool_playing(playing: bool) -> void:
	_ax_tool_playing = playing and not _ax_tool_timeline.is_empty()
	ax_play_pause.text = "Pause" if _ax_tool_playing else "Play"
	set_process(_ax_tool_playing)


func _ax_stream_dispatch_indices(stream: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	for untyped_command in stream.get("commands", []):
		var command: Dictionary = untyped_command
		if command.has("shared_record_index"):
			indices.append(int(command.shared_record_index))
	return indices


func _hide_ax_inspector() -> void:
	_set_ax_tool_playing(false)
	_ax_tool_scheduler.clear()
	_ax_tool_timeline.clear()
	_ax_tool_playback_plan.clear()
	_ax_drawable_records_by_index.clear()
	_ax_structural_records.clear()
	_ax_showing_structural_overview = false
	_ax_document = {}
	_ax_edited_document = {}
	_ax_source_data = PackedByteArray()
	_ax_edit_count = 0
	_ax_changed_cells.clear()
	_ax_changed_records.clear()
	_ax_details_base_text = ""
	_ax_selected_row = -1
	_ax_selected_column = -1
	_ax_selected_command_index = -1
	_ax_selected_record_index = -1
	_ax_cell_stream_indices.clear()
	if is_instance_valid(ax_inspector):
		ax_inspector.visible = false
	if is_instance_valid(ax_editor):
		ax_editor.visible = false
		ax_command_select.clear()
		ax_record_select.clear()
		ax_diagnostics.text = "No AX edits"
	if is_instance_valid(_ax_destination_overlay):
		_ax_destination_overlay.clear_records()
	if is_instance_valid(ax_play_pause):
		ax_play_pause.disabled = true
		ax_restart.disabled = true
		ax_clock_summary.text = "Tool clock unavailable"


func _ax_current_document() -> Dictionary:
	return _ax_edited_document if _ax_edit_count > 0 else _ax_document


func _ax_pending_edits_line() -> String:
	if _ax_edit_count <= 0:
		return "Pending timeline edits: none"
	var cell_keys: Array = _ax_changed_cells.keys()
	cell_keys.sort()
	var cell_parts: Array[String] = []
	for key in cell_keys:
		var pieces := str(key).split(",")
		cell_parts.append("(%s,%s)" % [pieces[0], pieces[1]])
	var record_keys: Array = _ax_changed_records.keys()
	record_keys.sort()
	var record_parts: Array[String] = []
	for key in record_keys:
		record_parts.append(str(int(key)))
	return "Pending timeline edits: %d (cells %s; records %s)" % [
		_ax_edit_count, ", ".join(cell_parts), ", ".join(record_parts)
	]


func _update_ax_details_pending_line() -> void:
	if not is_instance_valid(details) or _ax_details_base_text.is_empty():
		return
	details.text = "%s\n\n%s" % [_ax_details_base_text, _ax_pending_edits_line()]


func _ax_find_stream(streams: Array, row: int, column: int) -> Dictionary:
	for untyped_stream in streams:
		var stream: Dictionary = untyped_stream
		if int(stream.get("row", -1)) == row and int(stream.get("column", -1)) == column:
			return stream
	return {}


func _ax_opcode_kind_label(opcode: int) -> String:
	if opcode >= 9 and opcode <= 254:
		return "dispatch shared record"
	for item in AX_OPCODE_ITEMS:
		if int(item.opcode) == opcode:
			return str(item.label)
	return "0x%02X unknown" % opcode


func _ax_opcode_select_index(opcode: int) -> int:
	if opcode >= 9 and opcode <= 254:
		return AX_OPCODE_DISPATCH_ITEM_INDEX
	for index in range(AX_OPCODE_ITEMS.size()):
		if index == AX_OPCODE_DISPATCH_ITEM_INDEX:
			continue
		if int(AX_OPCODE_ITEMS[index].opcode) == opcode:
			return index
	return 0


func _ax_command_label(index: int, command: Dictionary) -> String:
	var opcode := int(command.get("opcode", -1))
	var kind := _ax_opcode_kind_label(opcode)
	var suffix := ""
	if opcode >= 9 and opcode <= 254:
		suffix = " · record %d" % int(command.get("shared_record_index", command.get("operand", -1)))
	elif command.has("operand"):
		suffix = " · operand %d" % int(command.operand)
	return "#%d · %s%s" % [index, kind, suffix]


func _ax_command_to_writer_dict(command: Dictionary) -> Dictionary:
	var opcode := int(command.get("opcode", -1))
	var built := {"opcode": opcode}
	if command.has("operand"):
		built["operand"] = int(command.operand)
	return built


func _ax_control_command() -> Dictionary:
	var select_index := ax_opcode_select.selected
	if select_index < 0 or select_index >= AX_OPCODE_ITEMS.size():
		select_index = 0
	var item: Dictionary = AX_OPCODE_ITEMS[select_index]
	var opcode := int(item.opcode)
	var built := {"opcode": opcode}
	if opcode in AX_U32_OPERAND_OPCODES or (opcode >= 9 and opcode <= 254):
		built["operand"] = int(ax_operand.value)
	return built


func _populate_ax_command_select(stream: Dictionary) -> void:
	_updating_ax_command_controls = true
	ax_command_select.clear()
	var commands: Array = stream.get("commands", [])
	for command_index in range(commands.size()):
		ax_command_select.add_item(_ax_command_label(command_index, commands[command_index]))
	var has_commands := not commands.is_empty()
	ax_command_select.disabled = not has_commands
	ax_command_apply.disabled = not has_commands
	ax_command_insert.disabled = not has_commands
	ax_command_remove.disabled = not has_commands
	ax_command_up.disabled = not has_commands
	ax_command_down.disabled = not has_commands
	if has_commands:
		_ax_selected_command_index = clampi(_ax_selected_command_index, 0, commands.size() - 1)
		ax_command_select.select(_ax_selected_command_index)
		_load_ax_command_controls(commands[_ax_selected_command_index])
	else:
		_ax_selected_command_index = -1
	_updating_ax_command_controls = false


func _load_ax_command_controls(command: Dictionary) -> void:
	_updating_ax_command_controls = true
	var opcode := int(command.get("opcode", -1))
	ax_opcode_select.select(_ax_opcode_select_index(opcode))
	var operand_value := 0
	if opcode >= 9 and opcode <= 254:
		operand_value = int(command.get("shared_record_index", command.get("operand", 0)))
	elif command.has("operand"):
		operand_value = int(command.operand)
	ax_operand.value = float(operand_value)
	_updating_ax_command_controls = false
	if opcode >= 9 and opcode <= 254:
		_select_ax_record(operand_value)


func _populate_ax_record_select(document: Dictionary) -> void:
	_updating_ax_record_controls = true
	ax_record_select.clear()
	var records: Array = document.get("shared_records", [])
	for record_index in range(records.size()):
		var record: Dictionary = records[record_index]
		ax_record_select.add_item("#%d · type %d · src %d,%d %dx%d → dst %d,%d" % [
			record_index,
			int(record.dispatch_type),
			int(record.source_x),
			int(record.source_y),
			int(record.width),
			int(record.height),
			int(record.destination_x),
			int(record.destination_y),
		])
	var has_records := not records.is_empty()
	ax_record_select.disabled = not has_records
	ax_record_apply.disabled = not has_records
	for control in [ax_record_type, ax_source_x, ax_source_y, ax_width, ax_height, ax_destination_x, ax_destination_y]:
		(control as SpinBox).editable = has_records
	if has_records:
		_ax_selected_record_index = clampi(_ax_selected_record_index, 0, records.size() - 1)
		ax_record_select.select(_ax_selected_record_index)
		_set_ax_record_controls(records[_ax_selected_record_index])
	else:
		_ax_selected_record_index = -1
	_updating_ax_record_controls = false


func _set_ax_record_controls(record: Dictionary) -> void:
	ax_record_type.value = int(record.dispatch_type)
	ax_source_x.value = int(record.source_x)
	ax_source_y.value = int(record.source_y)
	ax_width.value = int(record.width)
	ax_height.value = int(record.height)
	ax_destination_x.value = int(record.destination_x)
	ax_destination_y.value = int(record.destination_y)


func _select_ax_record(record_index: int) -> void:
	var document := _ax_current_document()
	var records: Array = document.get("shared_records", [])
	if record_index < 0 or record_index >= records.size():
		return
	_ax_selected_record_index = record_index
	_updating_ax_record_controls = true
	ax_record_select.select(record_index)
	_set_ax_record_controls(records[record_index])
	_updating_ax_record_controls = false


func _on_ax_command_selected(option_index: int) -> void:
	if _updating_ax_command_controls or _ax_selected_row < 0:
		return
	var document := _ax_current_document()
	var stream := _ax_find_stream(document.get("streams", []), _ax_selected_row, _ax_selected_column)
	var commands: Array = stream.get("commands", [])
	if option_index < 0 or option_index >= commands.size():
		return
	_ax_selected_command_index = option_index
	_load_ax_command_controls(commands[option_index])


func _on_ax_record_selected(option_index: int) -> void:
	if _updating_ax_record_controls:
		return
	var document := _ax_current_document()
	var records: Array = document.get("shared_records", [])
	if option_index < 0 or option_index >= records.size():
		return
	_ax_selected_record_index = option_index
	_updating_ax_record_controls = true
	_set_ax_record_controls(records[option_index])
	_updating_ax_record_controls = false


func _apply_ax_stream_edit(row: int, column: int, commands: Array, trailing_stop_ff: bool, next_selected_command_index: int) -> void:
	var result := _ax_writer.replace_stream(_ax_edited_document, row, column, commands, trailing_stop_ff)
	if not result.get("ok", false):
		status_label.text = "AX edit rejected: %s" % str(result.get("error", "unknown error"))
		return
	_ax_edited_document = result
	_ax_edit_count += 1
	_ax_changed_cells["%d,%d" % [row, column]] = true
	_ax_selected_row = row
	_ax_selected_column = column
	_ax_selected_command_index = next_selected_command_index
	_populate_ax_inspector()
	_update_ax_details_pending_line()
	status_label.text = "%s AX cell (%d,%d) timeline edited; %d edit(s) pending." % [
		_selected_name, row, column, _ax_edit_count,
	]


func _on_ax_command_apply_pressed() -> void:
	if _ax_selected_row < 0:
		status_label.text = "Select an AX cell first."
		return
	var document := _ax_current_document()
	var stream := _ax_find_stream(document.get("streams", []), _ax_selected_row, _ax_selected_column)
	if stream.is_empty():
		status_label.text = "Select an AX cell first."
		return
	var commands: Array = (stream.get("commands", []) as Array).duplicate(true)
	if _ax_selected_command_index < 0 or _ax_selected_command_index >= commands.size():
		status_label.text = "Select an existing AX command first."
		return
	var built_commands: Array = []
	for index in range(commands.size()):
		if index == _ax_selected_command_index:
			built_commands.append(_ax_control_command())
		else:
			built_commands.append(_ax_command_to_writer_dict(commands[index]))
	_apply_ax_stream_edit(
		_ax_selected_row, _ax_selected_column, built_commands,
		bool(stream.get("trailing_stop_ff", false)), _ax_selected_command_index
	)


func _on_ax_command_insert_pressed() -> void:
	if _ax_selected_row < 0:
		status_label.text = "Select an AX cell first."
		return
	var document := _ax_current_document()
	var stream := _ax_find_stream(document.get("streams", []), _ax_selected_row, _ax_selected_column)
	if stream.is_empty():
		status_label.text = "Select an AX cell first."
		return
	var commands: Array = (stream.get("commands", []) as Array).duplicate(true)
	var insert_at := 0 if commands.is_empty() else _ax_selected_command_index + 1
	insert_at = clampi(insert_at, 0, commands.size())
	var built_commands: Array = []
	for command_variant in commands:
		built_commands.append(_ax_command_to_writer_dict(command_variant))
	built_commands.insert(insert_at, _ax_control_command())
	_apply_ax_stream_edit(
		_ax_selected_row, _ax_selected_column, built_commands,
		bool(stream.get("trailing_stop_ff", false)), insert_at
	)


func _on_ax_command_remove_pressed() -> void:
	if _ax_selected_row < 0:
		status_label.text = "Select an AX cell first."
		return
	var document := _ax_current_document()
	var stream := _ax_find_stream(document.get("streams", []), _ax_selected_row, _ax_selected_column)
	if stream.is_empty():
		status_label.text = "Select an AX cell first."
		return
	var commands: Array = (stream.get("commands", []) as Array).duplicate(true)
	if _ax_selected_command_index < 0 or _ax_selected_command_index >= commands.size():
		status_label.text = "Select an existing AX command first."
		return
	var built_commands: Array = []
	for index in range(commands.size()):
		if index != _ax_selected_command_index:
			built_commands.append(_ax_command_to_writer_dict(commands[index]))
	var next_selection := clampi(_ax_selected_command_index, 0, maxi(0, built_commands.size() - 1))
	_apply_ax_stream_edit(
		_ax_selected_row, _ax_selected_column, built_commands,
		bool(stream.get("trailing_stop_ff", false)), next_selection
	)


func _on_ax_command_up_pressed() -> void:
	_move_ax_command(_ax_selected_command_index - 1)


func _on_ax_command_down_pressed() -> void:
	_move_ax_command(_ax_selected_command_index + 1)


func _move_ax_command(destination_index: int) -> void:
	if _ax_selected_row < 0:
		status_label.text = "Select an AX cell first."
		return
	var document := _ax_current_document()
	var stream := _ax_find_stream(document.get("streams", []), _ax_selected_row, _ax_selected_column)
	if stream.is_empty():
		status_label.text = "Select an AX cell first."
		return
	var commands: Array = (stream.get("commands", []) as Array).duplicate(true)
	if (
		_ax_selected_command_index < 0 or _ax_selected_command_index >= commands.size()
		or destination_index < 0 or destination_index >= commands.size()
	):
		status_label.text = "AX edit rejected: move target is outside the command list."
		return
	var built_commands: Array = []
	for command_variant in commands:
		built_commands.append(_ax_command_to_writer_dict(command_variant))
	var moved = built_commands[_ax_selected_command_index]
	built_commands.remove_at(_ax_selected_command_index)
	built_commands.insert(destination_index, moved)
	_apply_ax_stream_edit(
		_ax_selected_row, _ax_selected_column, built_commands,
		bool(stream.get("trailing_stop_ff", false)), destination_index
	)


func _on_ax_record_apply_pressed() -> void:
	var document := _ax_current_document()
	var records: Array = document.get("shared_records", [])
	if _ax_selected_record_index < 0 or _ax_selected_record_index >= records.size():
		status_label.text = "Select an existing AX shared record first."
		return
	var record := {
		"dispatch_type": int(ax_record_type.value),
		"source_x": int(ax_source_x.value),
		"source_y": int(ax_source_y.value),
		"width": int(ax_width.value),
		"height": int(ax_height.value),
		"destination_x": int(ax_destination_x.value),
		"destination_y": int(ax_destination_y.value),
	}
	var result := _ax_writer.replace_shared_record(_ax_edited_document, _ax_selected_record_index, record)
	if not result.get("ok", false):
		status_label.text = "AX edit rejected: %s" % str(result.get("error", "unknown error"))
		return
	_ax_edited_document = result
	_ax_edit_count += 1
	_ax_changed_records[_ax_selected_record_index] = true
	_populate_ax_inspector()
	_update_ax_details_pending_line()
	status_label.text = "%s AX shared record #%d edited; %d edit(s) pending." % [
		_selected_name, _ax_selected_record_index, _ax_edit_count,
	]


func _update_ax_diagnostics() -> void:
	if not is_instance_valid(ax_diagnostics):
		return
	if _ax_edit_count <= 0 or _ax_selected_row < 0:
		ax_diagnostics.text = "No AX edits"
		return
	var document := _ax_current_document()
	var stream := _ax_find_stream(document.get("streams", []), _ax_selected_row, _ax_selected_column)
	var command_count := (stream.get("commands", []) as Array).size()
	var serialized := _ax_writer.serialize(_ax_edited_document)
	var delta := int(serialized.get("byte_count", _ax_source_data.size())) - _ax_source_data.size()
	ax_diagnostics.text = "%d edit(s) pending · cell (%d,%d) %d commands · byte delta %+d" % [
		_ax_edit_count, _ax_selected_row, _ax_selected_column, command_count, delta,
	]


func _on_stage_ax_pressed() -> void:
	if _selected_name.get_extension().to_lower() != "ax" or _ax_document.is_empty():
		status_label.text = "Select and inspect an AX entry first."
		return
	if _ax_edit_count <= 0:
		status_label.text = "No pending AX timeline edits to stage."
		return
	var serialized := _ax_writer.serialize(_ax_edited_document)
	if not serialized.ok:
		status_label.text = "AX staging failed: %s" % serialized.error
		return
	var reopened := _ax_writer.reopen(serialized.data)
	if not reopened.ok:
		status_label.text = "AX staging failed: %s" % reopened.error
		return
	var changed_cells_array: Array = []
	var cell_keys: Array = _ax_changed_cells.keys()
	cell_keys.sort()
	for key in cell_keys:
		var pieces := str(key).split(",")
		changed_cells_array.append({"row": int(pieces[0]), "column": int(pieces[1])})
	var audit := _ax_writer.write_audit(_ax_source_data, serialized.data, changed_cells_array)
	if not audit.ok:
		status_label.text = "AX staging failed: %s" % audit.error
		return
	var entry := _reader.get_entry(_selected_name)
	if entry.is_empty():
		status_label.text = "AX staging failed: selected source entry is unavailable."
		return
	var staged := _stage_encoded_data(int(entry.index), "AX", serialized.data)
	if not staged.ok:
		status_label.text = "AX staging failed: %s" % staged.error
		return
	if _session.has(_selected_name):
		_remove_pending_files(_session[_selected_name])
	var changed_record_keys: Array = _ax_changed_records.keys()
	changed_record_keys.sort()
	var changed_record_indices: Array = []
	for key in changed_record_keys:
		changed_record_indices.append(int(key))
	_session[_selected_name] = {
		"kind": "AX",
		"path": staged.path,
		"sha256": staged.sha256,
		"size": serialized.data.size(),
		"original_size": _ax_source_data.size(),
		"delta": serialized.data.size() - _ax_source_data.size(),
		"changed_cells": changed_cells_array,
		"changed_records": changed_record_indices,
		"edit_operation": "timeline",
		"audit": audit,
		"compatibility": "original_engine_unverified",
	}
	_refresh_session_marks()
	_inspect_selected_ax()
	status_label.text = "%s AX staged and reopened: %d cell(s), %d record(s) changed, byte delta %+d; %d replacement(s) pending." % [
		_selected_name, changed_cells_array.size(), changed_record_indices.size(),
		serialized.data.size() - _ax_source_data.size(), _session.size(),
	]


func _on_revert_ax_pressed() -> void:
	if _selected_name.get_extension().to_lower() != "ax" or _ax_document.is_empty():
		status_label.text = "Select and inspect an AX entry first."
		return
	_ax_edited_document = _ax_document.duplicate(true)
	_ax_edit_count = 0
	_ax_changed_cells.clear()
	_ax_changed_records.clear()
	_populate_ax_inspector()
	_update_ax_details_pending_line()
	status_label.text = "%s AX timeline edits reverted." % _selected_name


func _clear_decoded_preview() -> void:
	_decoded_image = null
	preview.texture = null
	_surface_compositor.clear()
	game_preview.set_preview_texture(null)
	frame_footprint.text = "Preview-only placement"
	_update_selection_actions()


func _center_game_frame() -> void:
	if _decoded_image == null or _decoded_image.is_empty():
		return
	var image_size := _decoded_image.get_size()
	var centered := Vector2(
		floori((ContentToolGamePreview.LOGICAL_SIZE.x - image_size.x) / 2.0),
		floori((ContentToolGamePreview.LOGICAL_SIZE.y - image_size.y) / 2.0)
	)
	_set_frame_position(centered)


func _set_frame_position(position: Vector2) -> void:
	_updating_frame_position = true
	frame_x.value = position.x
	frame_y.value = position.y
	_updating_frame_position = false
	_present_decoded_game_frame()
	_update_frame_footprint()


func _on_frame_position_changed(_value: float) -> void:
	if _updating_frame_position or _decoded_image == null:
		return
	_present_decoded_game_frame()
	_update_frame_footprint()


func _present_decoded_game_frame() -> Dictionary:
	if _decoded_image == null or _decoded_image.is_empty():
		return {"ok": false, "error": "No decoded image is available for the logical frame."}
	_surface_compositor.clear()
	var logical_frame := Image.create(
		ContentToolGamePreview.LOGICAL_SIZE.x,
		ContentToolGamePreview.LOGICAL_SIZE.y,
		false,
		Image.FORMAT_RGB8
	)
	logical_frame.fill(Color.BLACK)
	var registered_frame := _surface_compositor.register_surface(0, logical_frame, "logical_frame")
	if not registered_frame.ok:
		return registered_frame
	var registered_source := _surface_compositor.register_surface(1, _decoded_image, "source")
	if not registered_source.ok:
		return registered_source
	var placement := Vector2i(roundi(frame_x.value), roundi(frame_y.value))
	var source_start := Vector2i(maxi(0, -placement.x), maxi(0, -placement.y))
	var destination_start := Vector2i(maxi(0, placement.x), maxi(0, placement.y))
	var visible_size := Vector2i(
		maxi(0, mini(_decoded_image.get_width() - source_start.x, ContentToolGamePreview.LOGICAL_SIZE.x - destination_start.x)),
		maxi(0, mini(_decoded_image.get_height() - source_start.y, ContentToolGamePreview.LOGICAL_SIZE.y - destination_start.y))
	)
	if visible_size.x > 0 and visible_size.y > 0:
		var composed := _surface_compositor.apply_operations_in_order([{
			"mode": 0,
			"source_x": source_start.x,
			"source_y": source_start.y,
			"inclusive_right": source_start.x + visible_size.x - 1,
			"inclusive_bottom": source_start.y + visible_size.y - 1,
			"source_surface_index": 1,
			"destination_x": destination_start.x,
			"destination_y": destination_start.y,
			"destination_surface_index": 0,
		}])
		if not composed.ok:
			return composed
	var presented := game_preview.present_compositor_surface(_surface_compositor)
	if not presented.ok:
		return presented
	presented["source_position"] = source_start
	presented["destination_position"] = destination_start
	presented["visible_size"] = visible_size
	presented["requested_position"] = placement
	return presented


func _on_center_frame_pressed() -> void:
	_center_game_frame()


func _update_frame_footprint() -> void:
	if _decoded_image == null or _decoded_image.is_empty():
		frame_footprint.text = "Preview-only placement"
		return
	var image_size := _decoded_image.get_size()
	frame_footprint.text = "%d×%d at (%d, %d) · preview only" % [
		image_size.x,
		image_size.y,
		int(frame_x.value),
		int(frame_y.value),
	]


func _on_import_pressed() -> void:
	if _selected_name.is_empty():
		status_label.text = "Select an MMO, DAT/PAL, or A6 entry first."
		return
	if _selected_name.get_extension().to_lower() == "a6":
		status_label.text = "A6 entries do not accept PNG replacements; edit an existing rectangle in the A6 panel below."
		return
	if _selected_name.get_extension().to_lower() == "ax":
		status_label.text = "AX entries are edited through the animation timeline (ME-02); PNG import does not apply."
		return
	replacement_dialog.popup_centered_ratio(0.75)


func _on_replacement_path_selected(path: String) -> void:
	if not _reader.is_open() or _reader.get_entry(_selected_name).is_empty():
		status_label.text = "The selected image entry is no longer available."
		return
	if _selected_name.get_extension().to_lower() in ["a6", "ax"]:
		status_label.text = "AX/A6 entries do not accept PNG replacements."
		return
	if not FileAccess.file_exists(path):
		status_label.text = "Replacement PNG does not exist."
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		status_label.text = "Replacement PNG could not be decoded."
		return
	if _selected_name.get_extension().to_lower() == "mmo":
		_stage_mmo_replacement(path, image)
	else:
		_stage_dat_pal_replacement(path, image)


func _stage_mmo_replacement(path: String, image: Image) -> void:
	_clear_quantization_candidate(true)
	var effective := _read_effective_entry(_selected_name)
	if not effective.ok:
		status_label.text = "Replacement rejected: %s" % effective.error
		return
	var template_data: PackedByteArray = effective.data
	if template_data.size() < _codec.HEADER_SIZE:
		status_label.text = "Resolved MMO header is truncated."
		return
	var encoded := _codec.encode_image(image, template_data.slice(0, _codec.HEADER_SIZE))
	if not encoded.ok:
		status_label.text = "Replacement rejected: %s" % encoded.error
		return
	var verified := _codec.decode_image(encoded.data)
	if not verified.ok or not _images_equal_rgb8(image, verified.image):
		status_label.text = "Replacement rejected: encoded MMO pixel verification failed."
		return
	var entry := _reader.get_entry(_selected_name)
	var staged := _stage_encoded_data(int(entry.index), "MMO", encoded.data)
	if not staged.ok:
		status_label.text = "Replacement staging failed: %s" % staged.error
		return
	if _session.has(_selected_name):
		_remove_pending_files(_session[_selected_name])
	_session[_selected_name] = {
		"kind": "MMO",
		"path": staged.path,
		"sha256": staged.sha256,
		"size": encoded.data.size(),
		"original_size": int(entry.size),
		"delta": encoded.data.size() - int(entry.size),
		"png_path": ProjectSettings.globalize_path(path).simplify_path(),
		"header_origin": encoded.header_origin,
		"header_profile": encoded.header_profile,
		"compatibility": encoded.compatibility,
	}
	_refresh_session_marks()
	_decode_selected()
	status_label.text = "%s staged and verified with %s header (%s); %d replacement(s) pending." % [
		_selected_name,
		str(encoded.header_profile),
		str(encoded.compatibility),
		_session.size(),
	]


func _stage_dat_pal_replacement(path: String, image: Image) -> void:
	_clear_quantization_candidate(true)
	var encoded := _dat_pal_codec.encode_image(image)
	if not encoded.ok:
		status_label.text = "Replacement rejected: %s" % encoded.error
		return
	var verified := _dat_pal_codec.decode_image(encoded.dat_data, encoded.pal_data)
	if not verified.ok:
		status_label.text = "Replacement rejected: encoded DAT/PAL pixel verification failed."
		return
	var diagnostics: Dictionary = encoded.get("diagnostics", {})
	if not _images_visibly_equal(image, verified.image, bool(verified.transparent_index_zero)):
		_present_quantization_comparison(path, image, verified.image, encoded, diagnostics)
		return
	var dat_entry := _reader.get_entry(_selected_name)
	var palette_name := "%s.PAL" % _selected_name.get_basename()
	var pal_entry := _reader.get_entry(palette_name)
	if pal_entry.is_empty():
		status_label.text = "Replacement rejected: paired PAL entry is missing."
		return
	var staged_dat := _stage_encoded_data(int(dat_entry.index), "DAT", encoded.dat_data)
	if not staged_dat.ok:
		status_label.text = "Replacement staging failed: %s" % staged_dat.error
		return
	var staged_pal := _stage_encoded_data(int(pal_entry.index), "PAL", encoded.pal_data)
	if not staged_pal.ok:
		_remove_session_file(str(staged_dat.path))
		status_label.text = "Replacement staging failed: %s" % staged_pal.error
		return
	if _session.has(_selected_name):
		_remove_pending_files(_session[_selected_name])
	var total_size: int = int(encoded.dat_data.size()) + int(encoded.pal_data.size())
	var original_size: int = int(dat_entry.size) + int(pal_entry.size)
	_session[_selected_name] = {
		"kind": "DAT/PAL",
		"authoring_origin": "png_import",
		"files": {
			_selected_name: {"path": staged_dat.path, "sha256": staged_dat.sha256, "size": encoded.dat_data.size()},
			palette_name: {"path": staged_pal.path, "sha256": staged_pal.sha256, "size": encoded.pal_data.size()},
		},
		"size": total_size,
		"original_size": original_size,
		"delta": total_size - original_size,
		"png_path": ProjectSettings.globalize_path(path).simplify_path(),
		"diagnostics_schema": str(encoded.get("diagnostics_schema", "")),
		"quantization_diagnostics": diagnostics.duplicate(true),
		"compatibility": "remake_only",
	}
	_refresh_session_marks()
	_decode_selected()
	status_label.text = "%s and %s staged and verified; %d image replacement(s) pending." % [_selected_name, palette_name, _session.size()]


func _present_quantization_comparison(
	path: String,
	source_image: Image,
	quantized_image: Image,
	encoded: Dictionary,
	diagnostics: Dictionary
) -> void:
	var dat_entry := _reader.get_entry(_selected_name)
	var palette_name := "%s.PAL" % _selected_name.get_basename()
	var pal_entry := _reader.get_entry(palette_name)
	if dat_entry.is_empty() or pal_entry.is_empty():
		status_label.text = "Replacement rejected: paired DAT/PAL entries are incomplete."
		return
	var staged_dat := _stage_encoded_data(int(dat_entry.index), "DAT", encoded.dat_data)
	if not staged_dat.ok:
		status_label.text = "Quantization comparison staging failed: %s" % str(staged_dat.error)
		return
	var staged_pal := _stage_encoded_data(int(pal_entry.index), "PAL", encoded.pal_data)
	if not staged_pal.ok:
		_remove_session_file(str(staged_dat.path))
		status_label.text = "Quantization comparison staging failed: %s" % str(staged_pal.error)
		return
	_quantization_candidate = {
		"entry_name": _selected_name,
		"palette_name": palette_name,
		"archive_sha256": _archive_sha256,
		"png_path": ProjectSettings.globalize_path(path).simplify_path(),
		"png_sha256": FileAccess.get_sha256(path),
		"files": {
			_selected_name: {"path": staged_dat.path, "sha256": staged_dat.sha256, "size": encoded.dat_data.size()},
			palette_name: {"path": staged_pal.path, "sha256": staged_pal.sha256, "size": encoded.pal_data.size()},
		},
		"diagnostics_schema": str(encoded.get("diagnostics_schema", "")),
		"diagnostics": diagnostics.duplicate(true),
		"source_image": source_image.duplicate(),
		"quantized_image": quantized_image.duplicate(),
		"original_size": int(dat_entry.size) + int(pal_entry.size),
	}
	before_texture.texture = ImageTexture.create_from_image(source_image)
	after_texture.texture = ImageTexture.create_from_image(quantized_image)
	quantization_summary.text = (
		"%s/%s · %d changed pixel(s) · RGB MAE %.3f · RMS %.3f · max channel error %d · "
		+ "%d source colors → %d palette entries. Index-zero alpha semantics are preserved."
	) % [
		_selected_name,
		palette_name,
		int(diagnostics.get("changed_pixel_count", 0)),
		float(diagnostics.get("mean_absolute_rgb_error", 0.0)),
		float(diagnostics.get("root_mean_square_rgb_error", 0.0)),
		int(diagnostics.get("maximum_channel_error", 0)),
		int(diagnostics.get("source_color_count", 0)),
		int(diagnostics.get("palette_color_count", 0)),
	]
	quantization_comparison.popup_centered(Vector2i(900, 560))
	status_label.text = "Replacement requires quantization: review the measured before/after comparison before staging."


func _on_accept_quantization_pressed() -> void:
	if _quantization_candidate.is_empty():
		status_label.text = "No DAT/PAL quantization comparison is awaiting approval."
		return
	var candidate := _quantization_candidate
	var entry_name := str(candidate.entry_name)
	var palette_name := str(candidate.palette_name)
	if (
		not _reader.is_open()
		or _selected_name != entry_name
		or _archive_sha256.is_empty()
		or str(candidate.archive_sha256) != _archive_sha256
		or FileAccess.get_sha256(_reader.archive_path) != _archive_sha256
	):
		_clear_quantization_candidate(true)
		status_label.text = "Quantization approval rejected: the open ARC or selected DAT/PAL target changed."
		return
	var dat_descriptor: Dictionary = candidate.files.get(entry_name, {})
	var pal_descriptor: Dictionary = candidate.files.get(palette_name, {})
	var dat_validated := _validate_descriptor(entry_name, dat_descriptor)
	var pal_validated := _validate_descriptor(palette_name, pal_descriptor)
	if not dat_validated.ok or not pal_validated.ok:
		_clear_quantization_candidate(true)
		status_label.text = "Quantization approval rejected: %s" % str(dat_validated.error if not dat_validated.ok else pal_validated.error)
		return
	var dat_data := FileAccess.get_file_as_bytes(str(dat_descriptor.path))
	var pal_data := FileAccess.get_file_as_bytes(str(pal_descriptor.path))
	var reopened := _dat_pal_codec.decode_image(dat_data, pal_data)
	if not reopened.ok or reopened.image.get_data() != (candidate.quantized_image as Image).get_data():
		_clear_quantization_candidate(true)
		status_label.text = "Quantization approval rejected: cached DAT/PAL pixels no longer match the reviewed result."
		return
	if _session.has(entry_name):
		_remove_pending_files(_session[entry_name])
	var total_size: int = int(dat_descriptor.size) + int(pal_descriptor.size)
	_session[entry_name] = {
		"kind": "DAT/PAL",
		"authoring_origin": "quantization_approved",
		"files": candidate.files.duplicate(true),
		"size": total_size,
		"original_size": int(candidate.original_size),
		"delta": total_size - int(candidate.original_size),
		"png_path": str(candidate.png_path),
		"source_png_sha256": str(candidate.png_sha256),
		"diagnostics_schema": str(candidate.diagnostics_schema),
		"quantization_diagnostics": (candidate.diagnostics as Dictionary).duplicate(true),
		"compatibility": "remake_only",
	}
	_clear_quantization_candidate(false)
	_refresh_session_marks()
	_decode_selected()
	status_label.text = "%s/%s quantization accepted and staged; %d image replacement(s) pending." % [
		entry_name, palette_name, _session.size(),
	]


func _on_reject_quantization_pressed() -> void:
	if _quantization_candidate.is_empty():
		quantization_comparison.hide()
		return
	var entry_name := str(_quantization_candidate.entry_name)
	_clear_quantization_candidate(true)
	status_label.text = "Rejected the DAT/PAL quantization candidate for %s; pending replacements are unchanged." % entry_name


func _clear_quantization_candidate(remove_files: bool) -> void:
	if remove_files and not _quantization_candidate.is_empty():
		for descriptor in (_quantization_candidate.get("files", {}) as Dictionary).values():
			_remove_session_file(str((descriptor as Dictionary).get("path", "")))
	_quantization_candidate.clear()
	if is_instance_valid(quantization_comparison):
		quantization_comparison.hide()
		before_texture.texture = null
		after_texture.texture = null
		quantization_summary.text = "No comparison candidate"


func _on_remove_replacement_pressed() -> void:
	if _selected_name.is_empty() or not _session.has(_selected_name):
		status_label.text = "Select an image with a pending replacement first."
		return
	_remove_pending_files(_session[_selected_name])
	_session.erase(_selected_name)
	_refresh_session_marks()
	_decode_selected()
	status_label.text = "Removed pending replacement for %s." % _selected_name


func _on_save_overlay_pressed() -> void:
	if not _require_session():
		return
	overlay_directory_dialog.popup_centered_ratio(0.75)


func _on_export_arc_pressed() -> void:
	if not _require_session():
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	export_arc_dialog.current_file = "%s-mod.arc" % archive_name.get_basename()
	export_arc_dialog.popup_centered_ratio(0.75)


func _require_session() -> bool:
	if not _reader.is_open():
		status_label.text = "Open an image ARC first."
		return false
	if _session.is_empty():
		status_label.text = "Import at least one verified image replacement first."
		return false
	return true


func _on_overlay_directory_selected(path: String) -> void:
	if not _require_session():
		return
	var collected := _collect_session_paths()
	if not collected.ok:
		status_label.text = "Overlay save stopped: %s" % collected.error
		return
	var archive_name := _reader.archive_path.replace("\\", "/").get_file()
	var result := OverlayPackageScript.new().stage_replacements_from_files(
		path,
		_reader,
		archive_name,
		collected.paths,
		collected.compatibility,
		"not_applicable"
	)
	if not result.ok:
		status_label.text = "Overlay save failed: %s" % result.error
		return
	var configured := _configure_loaded_overlay(path)
	_refresh_session_marks()
	status_label.text = (
		"Saved %d verified replacement(s) and loaded the overlay read layer: %s"
		% [_session.size(), result.manifest_path]
		if configured.ok
		else "Saved %d verified replacement(s), but overlay reload failed: %s" % [_session.size(), configured.error]
	)


func _on_export_arc_path_selected(path: String) -> void:
	if not _require_session():
		return
	if path.get_extension().to_lower() != "arc":
		status_label.text = "New archive output must use the .arc extension."
		return
	var collected := _collect_session_paths()
	if not collected.ok:
		status_label.text = "ARC export stopped: %s" % collected.error
		return
	var result := ArcProvenanceScript.new().materialize_repacked_copy_from_bound_files(
		_reader.archive_path,
		path,
		_archive_sha256,
		collected.bound_files,
		collected.compatibility
	)
	if not result.ok:
		status_label.text = "ARC export failed: %s" % result.error
		return
	status_label.text = "Verified ARC and provenance saved with %d image entry replacement(s): %s (source unchanged)" % [result.replacement_count, result.path]


func _collect_session_paths() -> Dictionary:
	var unordered: Dictionary = {}
	var compatibility := "original_engine_compatible"
	for logical_name in _session:
		var pending: Dictionary = _session[logical_name]
		if str(pending.kind) == "DAT/PAL":
			for target_name in pending.files:
				var validated := _validate_descriptor(str(target_name), pending.files[target_name])
				if not validated.ok:
					return validated
				if unordered.has(str(target_name)):
					return {"ok": false, "error": "The image session targets an ARC entry more than once: %s." % target_name}
				unordered[str(target_name)] = {"path": validated.path, "sha256": validated.sha256}
		else:
			var validated := _validate_pending(str(logical_name))
			if not validated.ok:
				return validated
			unordered[str(logical_name)] = {"path": validated.path, "sha256": validated.sha256}
		if str(pending.compatibility) != "original_engine_compatible":
			compatibility = "remake_only"
	var paths: Dictionary = {}
	var bound_files: Dictionary = {}
	for entry in _reader.get_entries():
		var entry_name := str(entry.name)
		if unordered.has(entry_name):
			var descriptor: Dictionary = unordered[entry_name]
			paths[entry_name] = descriptor.path
			bound_files[entry_name] = descriptor
	if paths.size() != unordered.size():
		return {"ok": false, "error": "The image session contains a target that is not in the open ARC."}
	return {"ok": true, "paths": paths, "bound_files": bound_files, "compatibility": compatibility}


func _refresh_session_marks() -> void:
	for entry_name in _entry_items:
		var item: TreeItem = _entry_items[entry_name]
		var entry := _reader.get_entry(str(entry_name))
		item.set_text(2, "%d%s" % [int(entry.size), _entry_source_suffix(str(entry_name))])
	_update_selection_actions()


func _images_equal_rgb8(left: Image, right: Image) -> bool:
	if left == null or right == null:
		return false
	var normalized: Image = left.duplicate()
	normalized.convert(Image.FORMAT_RGB8)
	return (
		normalized.get_width() == right.get_width()
		and normalized.get_height() == right.get_height()
		and normalized.get_data() == right.get_data()
	)


func _images_visibly_equal(left: Image, right: Image, transparent: bool) -> bool:
	if left == null or right == null or left.get_width() != right.get_width() or left.get_height() != right.get_height():
		return false
	var normalized: Image = left.duplicate()
	normalized.convert(Image.FORMAT_RGBA8 if transparent else Image.FORMAT_RGB8)
	var left_data := normalized.get_data()
	var right_data := right.get_data()
	if not transparent:
		return left_data == right_data
	for offset in range(0, left_data.size(), 4):
		var source_alpha := int(left_data[offset + 3])
		if source_alpha != int(right_data[offset + 3]):
			return false
		if source_alpha == 255 and left_data.slice(offset, offset + 3) != right_data.slice(offset, offset + 3):
			return false
	return true


func _stage_encoded_data(entry_index: int, extension: String, data: PackedByteArray) -> Dictionary:
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_session_root)
	if mkdir_error != OK:
		return {"ok": false, "error": "Could not create the image session cache (error %s)." % mkdir_error}
	var path := _session_root.path_join("%04d-%s.%s" % [entry_index, Time.get_ticks_usec(), extension])
	var temp_path := "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not create a temporary image payload."}
	file.store_buffer(data)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_session_file(temp_path)
		return {"ok": false, "error": "Could not write the temporary image payload."}
	var sha256 := OverlayPackageScript.sha256_bytes(data)
	if sha256.is_empty() or FileAccess.get_sha256(temp_path) != sha256:
		_remove_session_file(temp_path)
		return {"ok": false, "error": "Temporary image payload verification failed."}
	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		_remove_session_file(temp_path)
		return {"ok": false, "error": "Could not publish the staged image payload (error %s)." % rename_error}
	return {"ok": true, "path": path, "sha256": sha256}


func _load_pending(entry_name: String) -> Dictionary:
	var validated := _validate_pending(entry_name)
	if not validated.ok:
		return validated
	var data := FileAccess.get_file_as_bytes(validated.path)
	if data.size() != int(_session[entry_name].size):
		return {"ok": false, "error": "Pending image/layout payload size changed: %s." % entry_name}
	return {"ok": true, "path": validated.path, "data": data}


func _validate_pending(entry_name: String) -> Dictionary:
	if not _session.has(entry_name):
		return {"ok": false, "error": "No pending image/layout payload exists for %s." % entry_name}
	return _validate_descriptor(entry_name, _session[entry_name])


func _load_descriptor(entry_name: String, descriptor: Dictionary) -> Dictionary:
	var validated := _validate_descriptor(entry_name, descriptor)
	if not validated.ok:
		return validated
	var data := FileAccess.get_file_as_bytes(validated.path)
	if data.size() != int(descriptor.size):
		return {"ok": false, "error": "Pending image payload size changed: %s." % entry_name}
	return {"ok": true, "path": validated.path, "data": data}


func _validate_descriptor(entry_name: String, descriptor: Dictionary) -> Dictionary:
	if _reader.get_entry(entry_name).is_empty():
		return {"ok": false, "error": "Pending image target is not in the open ARC: %s." % entry_name}
	var path := str(descriptor.path)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Pending image payload is missing: %s." % entry_name}
	if FileAccess.get_sha256(path) != str(descriptor.sha256):
		return {"ok": false, "error": "Pending image payload changed after staging: %s." % entry_name}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(descriptor.size):
		if file != null:
			file.close()
		return {"ok": false, "error": "Pending image payload size changed: %s." % entry_name}
	file.close()
	return {"ok": true, "path": path, "sha256": str(descriptor.sha256), "size": int(descriptor.size)}


func _clear_session_files() -> void:
	for entry_name in _session:
		_remove_pending_files(_session[entry_name])
	_session.clear()
	if not _session_root.is_empty() and DirAccess.dir_exists_absolute(_session_root):
		DirAccess.remove_absolute(_session_root)


func _remove_session_file(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _remove_pending_files(pending: Dictionary) -> void:
	if str(pending.get("kind", "MMO")) == "DAT/PAL":
		for target_name in pending.files:
			_remove_session_file(str(pending.files[target_name].path))
	else:
		_remove_session_file(str(pending.path))


func _exit_tree() -> void:
	_clear_quantization_candidate(true)
	_clear_session_files()
	_launch_context.close()
	_resolver.close()


func _on_export_pressed() -> void:
	if _selected_name.get_extension().to_lower() in ["a6", "ax"]:
		status_label.text = "AX/A6 entries contain no directly decoded PNG image."
		return
	if _decoded_image == null or _decoded_image.is_empty():
		status_label.text = "Select and decode an MMO image first."
		return
	export_dialog.current_file = "%s.png" % _selected_name.get_basename()
	export_dialog.popup_centered_ratio(0.75)


func _on_export_path_selected(path: String) -> void:
	if _selected_name.is_empty() or _decoded_image == null or _decoded_image.is_empty():
		status_label.text = "Select and decode a visible MMO or DAT/PAL entry before exporting PNG."
		return
	if FileAccess.file_exists(path):
		status_label.text = "Output already exists; choose a new PNG path."
		return
	var error := _decoded_image.save_png(path)
	status_label.text = "Exported %s" % path if error == OK else "PNG export failed (error %s)." % error
