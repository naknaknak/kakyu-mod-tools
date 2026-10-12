extends "res://tools/content_suite/cli_script.gd"

const ImageEditorScene := preload("res://tools/content_suite/apps/image_arc_editor.tscn")

const MMO_ENTRY := "01CA_1.MMO"
const DAT_ENTRY := "CHARA.DAT"
const A6_ENTRY := "MENU1.A6"
const AX_ENTRY := "A01.AX"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("Usage: <mmo.arc> <data.arc>")
		return
	var mmo_path := ProjectSettings.globalize_path(str(arguments[0]))
	var data_path := ProjectSettings.globalize_path(str(arguments[1]))
	var source_hashes := {
		mmo_path: FileAccess.get_sha256(mmo_path),
		data_path: FileAccess.get_sha256(data_path),
	}
	if str(source_hashes[mmo_path]).is_empty() or str(source_hashes[data_path]).is_empty():
		_fail("Original image archives are unavailable.")
		return
	var editor: Control = ImageEditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	editor.call("_open_archive", mmo_path)
	var mmo_count := (editor.get("_image_entries") as Array).size()
	editor.set("_selected_name", MMO_ENTRY)
	editor.call("_decode_selected")
	var game_preview: ContentToolGamePreview = editor.get_node("Margin/Layout/Split/Right/PreviewTabs/GameFrame/GamePreview")
	if (
		mmo_count <= 0
		or editor.get("_decoded_image") == null
		or (editor.get("_decoded_image") as Image).get_size() != Vector2i(640, 400)
		or game_preview.get_frame_content_rect() != Rect2(Vector2.ZERO, Vector2(640, 400))
	):
		editor.queue_free()
		_fail("Image Editor did not present the original representative MMO at native game-frame pixels.")
		return
	editor.call("_open_archive", data_path)
	var data_count := (editor.get("_image_entries") as Array).size()
	editor.set("_selected_name", DAT_ENTRY)
	editor.call("_decode_selected")
	if (
		data_count <= 0
		or editor.get("_decoded_image") == null
		or (editor.get("_decoded_image") as Image).get_size() != Vector2i(640, 32)
		or game_preview.get_frame_content_rect() != Rect2(Vector2.ZERO, Vector2(640, 400))
		or game_preview.get_node("GameViewport/FrameRoot/FrameTexture").texture == null
		or not (editor.get("_session") as Dictionary).is_empty()
	):
		var decoded_size := Vector2i.ZERO
		if editor.get("_decoded_image") is Image:
			decoded_size = (editor.get("_decoded_image") as Image).get_size()
		var dat_diagnostic := "entries=%d decoded=%s frame=%s session=%d status=%s" % [
			data_count,
			str(decoded_size),
			str(game_preview.get_frame_content_rect()),
			(editor.get("_session") as Dictionary).size(),
			str((editor.get_node("Margin/Layout/StatusLabel") as Label).text),
		]
		editor.queue_free()
		_fail("Image Editor did not present the original representative DAT/PAL strip without staging a change: %s" % dat_diagnostic)
		return
	editor.set("_selected_name", A6_ENTRY)
	editor.call("_decode_selected")
	var a6_overlay: ContentToolA6RegionOverlay = editor.get("_a6_region_overlay")
	var a6_rect := a6_overlay.get_region_rect(0)
	if (
		a6_overlay.get_region_count() != 1
		or a6_rect.size.x <= 0.0
		or a6_rect.size.y <= 0.0
		or editor.get("_decoded_image") != null
		or not (editor.get("_session") as Dictionary).is_empty()
	):
		editor.queue_free()
		_fail("Image Editor did not project the original representative A6 input region without staging a change.")
		return
	editor.call("_on_game_preview_pointer_pressed", a6_rect.get_center())
	if a6_overlay.get_selected_index() != 0:
		editor.queue_free()
		_fail("Image Editor did not select the original A6 region through the confirmed first-match hit test.")
		return
	editor.set("_selected_name", AX_ENTRY)
	editor.call("_decode_selected")
	var ax_overlay: ContentToolAxDestinationOverlay = editor.get("_ax_destination_overlay")
	var ax_dispatch_count := ax_overlay.get_dispatch_count()
	var ax_scheduler: KakyuAxToolScheduler = editor.get("_ax_tool_scheduler")
	var ax_playback_plan: Dictionary = editor.get("_ax_tool_playback_plan")
	var ax_clock_summary: Label = editor.get_node("Margin/Layout/Split/Right/AXInspector/AXClockSummary")
	if (
		ax_dispatch_count <= 0
		or editor.get("_decoded_image") != null
		or str(ax_playback_plan.get("schema", "")) != "kakyu_ax_playback_plan/v2"
		or (ax_playback_plan.get("frames", []) as Array).is_empty()
		or not bool(ax_scheduler.snapshot().get("configured", false))
		or not ax_clock_summary.text.contains("native cadence unconfirmed")
		or not (editor.get("_session") as Dictionary).is_empty()
	):
		editor.queue_free()
		_fail("Image Editor did not project a confirmed destination reference from the original representative AX cell.")
		return
	var ax_structural_records: Array = editor.get("_ax_structural_records")
	if ax_structural_records.is_empty():
		editor.queue_free()
		_fail("Image Editor selected AX cell has no drawable record to edit.")
		return
	var ax_record_index := int((ax_structural_records[0] as Dictionary).shared_record_index)
	var ax_record_select: OptionButton = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXRecordSelect")
	var ax_destination_x: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXDestinationX")
	var ax_destination_y: SpinBox = editor.get_node("Margin/Layout/Split/Right/AXEditor/RecordRow/AXDestinationY")
	ax_record_select.select(ax_record_index)
	editor.call("_on_ax_record_selected", ax_record_index)
	var expected_destination_x := int(ax_destination_x.value) + 1
	var expected_destination_y := int(ax_destination_y.value) + 1
	ax_destination_x.value = expected_destination_x
	ax_destination_y.value = expected_destination_y
	editor.call("_on_ax_record_apply_pressed")
	if int(editor.get("_ax_edit_count")) != 1:
		editor.queue_free()
		_fail("Image Editor did not track a single AX record edit against the original representative AX cell.")
		return
	editor.call("_on_stage_ax_pressed")
	var ax_session: Dictionary = editor.get("_session")
	if not ax_session.has(AX_ENTRY) or str(ax_session[AX_ENTRY].kind) != "AX":
		editor.queue_free()
		_fail("Image Editor did not stage the edited AX timeline into the session.")
		return
	var ax_staged_path := str(ax_session[AX_ENTRY].path)
	var ax_reopened := KakyuAxWriter.new().reopen(FileAccess.get_file_as_bytes(ax_staged_path))
	var ax_reopened_record: Dictionary = (
		(ax_reopened.get("animation", {}) as Dictionary).get("shared_records", []) as Array
	)[ax_record_index] if ax_reopened.get("ok", false) else {}
	if (
		not ax_reopened.get("ok", false)
		or int(ax_reopened_record.get("destination_x", -1)) != expected_destination_x
		or int(ax_reopened_record.get("destination_y", -1)) != expected_destination_y
		or int(ax_session[AX_ENTRY].audit.byte_delta) != 0
	):
		editor.queue_free()
		_fail("Image Editor staged AX session item did not reopen with the edited destination and a zero byte delta.")
		return
	editor.call("_on_remove_replacement_pressed")
	if not (editor.get("_session") as Dictionary).is_empty():
		editor.queue_free()
		_fail("Image Editor did not remove the pending AX session item on request.")
		return
	var sources_unchanged := (
		FileAccess.get_sha256(mmo_path) == str(source_hashes[mmo_path])
		and FileAccess.get_sha256(data_path) == str(source_hashes[data_path])
	)
	editor.queue_free()
	await process_frame
	if not sources_unchanged:
		_fail("Image Editor changed an original archive during read-only validation.")
		return
	print(
		"PASS: Image Editor original integration MMO=%s 640x400 DAT/PAL=%s 640x32 A6=%s first_match=true AX=%s destination_refs=%d shared_tool_clock=true native_cadence_unconfirmed game_frame=640x400 entries=%d/%d session=empty sources_unchanged=true ax_edit_staged=true ax_audit=kakyu_ax_write_audit/v1"
		% [MMO_ENTRY, DAT_ENTRY, A6_ENTRY, AX_ENTRY, ax_dispatch_count, mmo_count, data_count]
	)
	quit(0)
