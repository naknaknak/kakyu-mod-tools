extends "res://tests/test_case.gd"

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const ArcProvenanceScript := preload("res://content_core/arc_provenance.gd")
const OverlayPackageScript := preload("res://content_core/overlay_package.gd")
const MmoCodecScript := preload("res://content_core/mmo_codec.gd")
const MesTextPatcherScript := preload("res://content_core/mes_text_patcher.gd")
const MesInstructionDecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const ToolPathHistoryScript := preload("res://tools/content_suite/tool_path_history.gd")
const SyntheticArc := preload("res://tests/synthetic_arc.gd")

const TEST_ROOT := "user://event_player_test"


func _ready() -> void:
	_cleanup()
	var absolute_root := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var archive_path := TEST_ROOT + "/mes.arc"
	var image_archive_path := TEST_ROOT + "/mmo.arc"
	var data_archive_path := TEST_ROOT + "/data.arc"
	var bgm_archive_path := TEST_ROOT + "/bgm.arc"
	var voice_archive_path := TEST_ROOT + "/voice.arc"
	var cache_root := TEST_ROOT + "/text_cache"
	var overlay_root := TEST_ROOT + "/my_mod"
	var mes := _synthetic_mes()
	var source_image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	source_image.fill(Color(0.2, 0.4, 0.8))
	var encoded_image: Dictionary = MmoCodecScript.new().encode_image(source_image)
	var ax_data := _synthetic_ax()
	SyntheticArc.write_arc(archive_path, [{"name": "TEST.MES", "data": mes}])
	SyntheticArc.write_arc(image_archive_path, [{"name": "BACK.MMO", "data": encoded_image.data}])
	SyntheticArc.write_arc(data_archive_path, [{"name": "BACK.AX", "data": ax_data}])
	SyntheticArc.write_arc(bgm_archive_path, [{"name": "X_MAS.WAV", "data": _synthetic_wav()}])
	SyntheticArc.write_arc(voice_archive_path, [{"name": "XQZ01.OGG", "data": _synthetic_ogg()}])
	_create_text_cache(cache_root, archive_path, "TEST.MES", mes)
	var pristine_mes_archive_bytes := FileAccess.get_file_as_bytes(archive_path)
	var source_sha := FileAccess.get_sha256(archive_path)
	var image_source_sha := FileAccess.get_sha256(image_archive_path)
	var data_source_sha := FileAccess.get_sha256(data_archive_path)
	var bgm_source_sha := FileAccess.get_sha256(bgm_archive_path)
	var voice_source_sha := FileAccess.get_sha256(voice_archive_path)

	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	player.set("_path_history", ToolPathHistoryScript.new(TEST_ROOT.path_join("path_history.cfg")))
	player.window_display_config_path = TEST_ROOT.path_join("window_display.cfg")
	add_child(player)
	await get_tree().process_frame
	await _test_catalog_preset_selector_ui(player)
	var playback_sources: Control = player.get_node("Margin/Layout/MainSplit/Sources")
	var playback_intro: Control = player.get_node("Margin/Layout/MainSplit/Right/RunBar/IntroEdit")
	var playback_run: Control = player.get_node("Margin/Layout/MainSplit/Right/RunBar/Run")
	var playback_fragment: Control = player.get_node("Margin/Layout/MainSplit/Right/RunBar/PreviewFragment")
	var playback_diagnostics: Control = player.get_node("Margin/Layout/MainSplit/Right/PreviewDiagnostics")
	var playback_work_tabs: Control = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs")
	var playback_status: Control = player.get_node("Margin/Layout/StatusLabel")
	var playback_game: Control = player.get_node("Margin/Layout/MainSplit/Right/GamePreview")
	var runtime_runner = player.get("_runner")
	var runtime_state = player.get("_state")
	var runtime_resolver = player.get("_resolver")
	_check(
		not player.has_node("Margin/Layout/Toolbar/Overlay")
		and not player.has_node("Margin/Layout/Toolbar/HotReload")
		and not player.has_node("Margin/Layout/Toolbar/ClearOverlay")
		and not player.has_node("Margin/Layout/Toolbar/MaterializedLayers")
		and not player.has_node("OverlayDialog")
		and not player.has_node("MaterializedArcDialog")
		and not player.has_node("MaterializedWindow")
		and not player.has_method("_configure_overlay")
		and not player.has_method("_prepare_overlay_candidate")
		and not player.has_method("_on_overlay_pressed")
		and not player.has_method("_on_overlay_selected")
		and not player.has_method("_on_hot_reload_pressed")
		and not player.has_method("_on_clear_overlay_pressed")
		and not player.has_method("_configure_materialized_archives")
		and player.get("_overlay_text_messages") == null
		and player.get("_overlay_root") == null
		and player.get("_materialized_archive_snapshots") == null,
		"Event Player removes the overlay and derived-layer affordances and their state"
	)
	_check(
		str(player.get("_view_mode")) == "playback"
		and (player.get_node("Margin/Layout/Toolbar/ViewMode") as OptionButton).selected == 0,
		"Event Player starts in Playback view"
	)
	_check(
		not playback_sources.visible
		and not playback_intro.visible
		and not playback_run.visible
		and not playback_fragment.visible
		and not playback_diagnostics.visible
		and not playback_work_tabs.visible
		and not playback_status.visible
		and playback_game.visible
		and (player.get_node("Margin/Layout/Toolbar/Catalog") as Button).visible
		and (player.get("start_event_button") as Button).visible
		and (player.get("continue_button") as Button).visible
		and (player.get("bgm_toggle_button") as Button).visible,
		"Playback view shows event-facing controls while hiding source, trace, state, and boundary diagnostics"
	)
	var invalid_mode: Dictionary = player.set_view_mode("unsupported")
	_check(not invalid_mode.ok and str(player.get("_view_mode")) == "playback", "unknown Event Player view modes fail closed")
	player.set_view_mode("analysis")
	_check(
		str(player.get("_view_mode")) == "analysis"
		and playback_sources.visible
		and playback_intro.visible
		and playback_run.visible
		and playback_fragment.visible
		and playback_diagnostics.visible
		and playback_work_tabs.visible
		and playback_status.visible
		and is_same(runtime_runner, player.get("_runner"))
		and is_same(runtime_state, player.get("_state"))
		and is_same(runtime_resolver, player.get("_resolver")),
		"Analysis restores evidence controls on the same runner, sandbox, and resolver"
	)
	player.set("_document", {
		"bytecode": PackedByteArray([0x18, 0x01, 0xFF, 0x00, 0x00]),
		"header": {"code_size": 5, "entry_offsets": [3, 4]},
	})
	player.run_from_offset(0)
	_check(
		str(player.get("_preview_result_status")) == "script_return"
		and int(player.get("_preview_result_offset")) == 4,
		"Event Player supplies the selected MES document address table to command 0x18"
	)
	var retained_status := str(player.get("_preview_result_status"))
	var retained_offset := int(player.get("_preview_result_offset"))
	player.set_view_mode("playback")
	player.set_view_mode("analysis")
	_check(
		str(player.get("_preview_result_status")) == retained_status
		and int(player.get("_preview_result_offset")) == retained_offset
		and is_same(runtime_runner, player.get("_runner"))
		and is_same(runtime_state, player.get("_state")),
		"switching Playback and Analysis preserves the active execution result and sandbox"
	)
	player.set("_document", {"header": {"code_size": 4}})
	var native_dispatch_instruction: Dictionary = MesInstructionDecoderScript.new().decode_at(PackedByteArray([0x12, 0x00]), 0)
	_check(
		str(player._library_instruction_detail(native_dispatch_instruction)).contains("typed records"),
		"Event Player labels command 0x12 as a native typed-record dispatch"
	)
	var synthetic_library := PackedByteArray()
	SyntheticArc.append_registration(synthetic_library, 40, PackedByteArray([
		0x12,
		0x02, 0x01, 0xFF,
		0x02, 0x2B, 0xFF,
		0x02, 0x00, 0xFF,
		0x00,
		0x00,
	]))
	var control_flow_body_offset := synthetic_library.size() + 7
	var control_flow_body := PackedByteArray([0x0C, 0, 0, 0, 0, 0x00, 0x00])
	control_flow_body.encode_u32(1, control_flow_body_offset + 6)
	SyntheticArc.append_registration(synthetic_library, 41, control_flow_body)
	SyntheticArc.append_registration(synthetic_library, 42, PackedByteArray([
		0x03, 0x1E, 0x00, 0x02, 0xFF, 0x00,
		0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x03, 0x1F, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	]))
	synthetic_library.append(0x00)
	var synthetic_library_index := MesLibraryIndexScript.new().build(synthetic_library)
	player.set("_library_document", {"bytecode": synthetic_library})
	player.set("_library_index", synthetic_library_index)
	var synthetic_routine: Dictionary = synthetic_library_index.by_id[40]
	player._populate_shared_routine_tree({
		"routine_id": 40,
		"body_offset": int(synthetic_routine.body_offset),
		"end_offset": int(synthetic_routine.end_offset),
		"source": "synthetic",
	})
	var shared_tree: Tree = player.get("shared_routine_tree")
	var shadowed_rows: Array = shared_tree.get_meta("native_dispatch_shadowed_structural_instructions", [])
	var record_item: TreeItem = shared_tree.get_root().get_first_child()
	_check(
		shadowed_rows.is_empty()
		and record_item.get_text(1).contains("native_record_dispatch")
		and record_item.get_text(2).contains("3 typed records"),
		"Event Player presents command 0x12 records without fabricating command rows from payload bytes"
	)
	var control_flow_routine: Dictionary = synthetic_library_index.by_id[41]
	player._populate_shared_routine_tree({
		"routine_id": 41,
		"body_offset": int(control_flow_routine.body_offset),
		"end_offset": int(control_flow_routine.end_offset),
		"source": "synthetic",
	})
	var control_flow_rows: Array = shared_tree.get_meta("native_dispatch_unreached_structural_instructions", [])
	var control_flow_item: TreeItem = shared_tree.get_root().get_first_child().get_next()
	_check(
		control_flow_rows.size() == 1
		and str(control_flow_rows[0].reason) == "control_flow_not_reached"
		and control_flow_item.get_text(1).contains("not reached by native dispatch graph")
		and control_flow_item.get_text(2).contains("no edge in the both-branch native dispatch graph"),
		"Event Player marks stored rows excluded by native control flow"
	)
	player.set("_document", {
		"ok": true,
		"bytecode": PackedByteArray([0x00]),
		"header": {"code_size": 1, "entry_offsets": []},
	})
	player._run_library_and_resume(0, {"routine_id": 42})
	var library_dialogue_context: Dictionary = player.get("_continuation_context")
	_check(
		str(player.get("_preview_result_status")) == "library_dialogue_boundary"
		and int(player.get("_continuation_offset")) == 0
		and str(library_dialogue_context.get("kind", "")) == "library_dialogue"
		and str(library_dialogue_context.get("library_frame_continuation", {}).get("schema", "")) == "kakyu_mes_library_continuation/v2"
		and (player.get("continue_button") as Button).text == "Continue Library Dialogue"
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 30) == 2
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 31) == 0,
		"Event Player exposes a shared-library dialogue without returning early to the MES caller"
	)
	player.advance()
	_check(
		str(player.get("_preview_result_status")) == "script_return"
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 31) == 4,
		"Event Player resumes the source-bound library frame before restoring the MES caller"
	)
	(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", 30, 0, 0)
	(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", 31, 0, 0)
	player._run_library_and_resume(0, {"routine_id": 42})
	player.set("_document", {
		"ok": true,
		"bytecode": PackedByteArray([0x00, 0x00]),
		"header": {"code_size": 2, "entry_offsets": []},
	})
	player.advance()
	_check(
		str((player.get("status_label") as Label).text).contains("MES caller changed")
		and int(player.get("_continuation_offset")) == -1
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 31) == 0,
		"Event Player rejects a changed MES caller before resuming a library dialogue"
	)
	player.set("_document", {
		"ok": true,
		"bytecode": PackedByteArray([0x00]),
		"header": {"code_size": 1, "entry_offsets": []},
	})
	player._run_library_and_resume(0, {"routine_id": 42})
	var changed_library: PackedByteArray = synthetic_library.duplicate()
	var dialogue_routine: Dictionary = synthetic_library_index.by_id[42]
	changed_library[int(dialogue_routine.body_offset) + 7] = 0x42
	player.set("_library_document", {"bytecode": changed_library})
	player.advance()
	_check(
		str(player.get("_preview_result_status")) == "invalid_continuation"
		and int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 31) == 0,
		"Event Player rejects a changed library before resuming its dialogue frame"
	)
	player.set("_library_document", {"bytecode": synthetic_library})
	var registered_root := PackedByteArray([
		0x03, 0x20, 0x00, 0x02, 0xFF, 0x00,
		0x11, 0x02, 0x29, 0xFF, 0x00,
		0x03, 0x21, 0x00, 0x04, 0xFF, 0x00,
		0x00,
	])
	var registered_body := PackedByteArray([
		0x01, 0x41, 0x00, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x03, 0x22, 0x00, 0x03, 0xFF, 0x00,
		0x00,
	])
	var registered_registry := {41: {
		"code": registered_body,
		"body_offset": 0,
		"end_offset": registered_body.size(),
		"source": "synthetic registered DEF 41",
		"source_entry": "DEF_TEST.MES",
	}}
	player.set("_document", {
		"ok": true,
		"bytecode": registered_root,
		"header": {"code_size": registered_root.size(), "entry_offsets": []},
	})
	for index in [32, 33, 34]:
		(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", index, 0, 0)
	var registered_boundary: Dictionary = player.get("_runner").run(
		registered_root,
		0,
		player.get("_state"),
		registered_root.size()
	)
	player._attach_registered_definition_context(registered_boundary, registered_registry)
	player._show_result(registered_boundary, 0)
	var registered_start_context: Dictionary = player.get("_continuation_context")
	_check(
		str(player.get("_preview_result_status")) == "definition_invoke_boundary"
		and str(registered_start_context.get("kind", "")) == "registered_definition_start"
		and int(player.get("_continuation_offset")) == 6
		and (player.get("continue_button") as Button).text == "Continue (Run Registered DEF)"
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 32) == 2,
		"Event Player exposes an explicitly registered DEF invocation without inventing its selector"
	)
	player.advance()
	var registered_dialogue_context: Dictionary = player.get("_continuation_context")
	_check(
		str(player.get("_preview_result_status")) == "registered_definition_dialogue_boundary"
		and str(registered_dialogue_context.get("kind", "")) == "registered_definition_dialogue"
		and str(registered_dialogue_context.get("registered_definition_continuation", {}).get("schema", "")) == "kakyu_mes_registered_definition_continuation/v1"
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 34) == 0
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 33) == 0,
		"Event Player pauses at dialogue inside a registered DEF before restoring its MES caller"
	)
	player.advance()
	_check(
		str(player.get("_preview_result_status")) == "script_return"
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 34) == 3
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 33) == 4,
		"Event Player resumes the registered DEF body before its exact MES caller coordinate"
	)
	for index in [32, 33, 34]:
		(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", index, 0, 0)
	registered_boundary = player.get("_runner").run(
		registered_root,
		0,
		player.get("_state"),
		registered_root.size()
	)
	player._attach_registered_definition_context(registered_boundary, registered_registry)
	player._show_result(registered_boundary, 0)
	player.advance()
	var changed_registered_context: Dictionary = player.get("_continuation_context").duplicate(true)
	var changed_registered_registry: Dictionary = changed_registered_context.get("registered_definition_registry", {})
	var changed_registered_definition: Dictionary = changed_registered_registry[41]
	var changed_registered_code: PackedByteArray = changed_registered_definition.code.duplicate()
	changed_registered_code[1] = 0x42
	changed_registered_definition["code"] = changed_registered_code
	changed_registered_registry[41] = changed_registered_definition
	changed_registered_context["registered_definition_registry"] = changed_registered_registry
	player.set("_continuation_context", changed_registered_context)
	player.advance()
	_check(
		str(player.get("_preview_result_status")) == "invalid_continuation"
		and int(player.get("_continuation_offset")) == -1
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 34) == 0
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 33) == 0,
		"Event Player rejects a changed registered DEF before body or caller restoration"
	)
	for index in [32, 33, 34]:
		(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", index, 0, 0)
	registered_boundary = player.get("_runner").run(
		registered_root,
		0,
		player.get("_state"),
		registered_root.size()
	)
	player._attach_registered_definition_context(registered_boundary, registered_registry)
	player._show_result(registered_boundary, 0)
	player.advance()
	var changed_registered_root: PackedByteArray = registered_root.duplicate()
	changed_registered_root[1] = 0x21
	player.set("_document", {
		"ok": true,
		"bytecode": changed_registered_root,
		"header": {"code_size": changed_registered_root.size(), "entry_offsets": []},
	})
	player.advance()
	_check(
		str((player.get("status_label") as Label).text).contains("MES caller changed")
		and int(player.get("_continuation_offset")) == -1
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 34) == 0
		and (player.get("_state") as KakyuMesSandboxState).read_value("global_u8", 33) == 0,
		"Event Player rejects a changed MES caller before resuming a registered DEF dialogue"
	)
	player.set("_document", {
		"ok": true,
		"bytecode": PackedByteArray([0x00]),
		"header": {"code_size": 1, "entry_offsets": []},
	})
	var native_presentation_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x12, 0x02, 0x01, 0xFF, 0x02, 0x2B, 0xFF, 0x02, 0x00, 0xFF, 0x00, 0x00]),
		0,
		player.get("_state")
	)
	player._show_result(native_presentation_result, 0)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("Native typed-record dispatch")
		and (player.get("_preview_footer_label") as Label).text.contains("3 records")
		and not (player.get("_preview_footer_label") as Label).text.contains("Continue explicitly omits")
		and int(player.get("_continuation_offset")) == -1
		and (player.get("_continuation_context") as Dictionary).is_empty()
		and native_presentation_result.state_diff.is_empty(),
		"Event Player explains an ordinary command 0x12 record boundary while keeping continuation fail-closed"
	)
	var state_transfer_result: Dictionary = player.get("_runner").run(
		PackedByteArray([
			0x0D, 0x04, 0xFF, 0x02, 0x0D, 0xFF,
			0x02, 0xF8, 0x2B, 0xFF,
			0x01, 0x48, 0x54, 0x45, 0x00,
			0x00, 0x00,
		]),
		0,
		player.get("_state")
	)
	player._show_result(state_transfer_result, 0)
	_check(
		str(player.get("_preview_result_status")) == "native_state_transfer_boundary"
		and (player.get("_preview_message_label") as Label).text.contains("Relative offset slots HTE")
		and (player.get("_preview_footer_label") as Label).text.contains("record contents/physical aliases unresolved")
		and (player.get("output") as RichTextLabel).text.contains("Native state transfer")
		and state_transfer_result.state_diff.is_empty(),
		"Event Player explains the confirmed native offset transfer outside sandbox execution"
	)
	player.set("_selected_entry", "DEF_MAIN.MES")
	player.set("_document", {
		"entry_sha256": "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0",
		"header": {"code_size": 0x042D},
	})
	player.set("_preview_event_session", "def26_isolated_body")
	var def26_native_result := {
		"status": "native_record_boundary",
		"offset": 0x0208,
		"command_id": 0x12,
		"trace": [{
			"command_id": 0x12,
			"source_offset": 0x0208,
			"end_offset": 0x0216,
			"effect": "native_record_boundary",
			"native_record_consumption": "typed_record_list_until_zero",
			"native_record_count": 4,
			"native_record_terminator_consumed": true,
		}],
	}
	player._capture_continuation(def26_native_result)
	_check(
		int(player.get("_continuation_offset")) == 0x0216
		and str((player.get("_continuation_context") as Dictionary).get("kind", "")) == "def26_native_records_omitted"
		and str((player.get("_continuation_context") as Dictionary).get("native_record_policy", "")) == "omit_bounded"
		and (player.get_node("Margin/Layout/MainSplit/Right/RunBar/Continue") as Button).text == "Continue (Omit Body Records)",
		"Event Player permits the exact hash-bound DEF26 isolated-body omission"
	)
	var shifted_def26_result: Dictionary = def26_native_result.duplicate(true)
	shifted_def26_result["offset"] = 0x0209
	player._capture_continuation(shifted_def26_result)
	_check(
		int(player.get("_continuation_offset")) == -1
		and (player.get_node("Margin/Layout/MainSplit/Right/RunBar/Continue") as Button).disabled,
		"Event Player rejects a shifted DEF26 native boundary instead of using a generic continuation"
	)
	player.set("_document", {
		"ok": true,
		"bytecode": PackedByteArray([0x00]),
		"header": {"code_size": 1, "entry_offsets": []},
		"source": {"resolved_source": "original_arc"},
	})
	(player.get_node("Margin/Layout/MainSplit/Right/RunBar/IntroEdit") as LineEdit).text = "0x0"
	player._on_run_pressed()
	_check(
		str(player.get("_preview_event_session")).is_empty()
		and int(player.get("_continuation_offset")) == -1,
		"Manual Intro runs clear stale route identity before execution"
	)
	var native_double_byte_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x01, 0xFF]),
		0,
		player.get("_state")
	)
	player._show_result(native_double_byte_result, 0)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("Native double-byte character-stream presentation reached")
		and (player.get("_preview_footer_label") as Label).text.contains("0 probed bytes")
		and native_double_byte_result.messages.is_empty()
		and native_double_byte_result.state_diff.is_empty(),
		"Event Player distinguishes an empty command 0x01 native boundary from dialogue"
	)
	var d_pic_anchors: Array = player._confirmed_preview_anchors("D_PIC.MES", "72473432ce3dd6e0fc1e994a737dbecd5494eaf4477efc24368d3b3160d7fecd")
	_check(d_pic_anchors.size() == 6 and int(d_pic_anchors[0].offset) == 0xCC, "Event Player exposes the six hash-bound confirmed D_PIC preview anchors")
	_check((player._confirmed_preview_anchors("D_PIC.MES", "00") as Array).is_empty(), "Event Player hides confirmed anchors when the resolved MES hash differs")
	var nested_44c_anchors: Array = player._confirmed_preview_anchors("44C.MES", "49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce")
	var nested_hotel_anchors: Array = player._confirmed_preview_anchors("L_HOTEL2.MES", "5ed3ba5238949f180a8da82961df9d9fe6b8bf818dbc7cf464c84ac38de85e49")
	_check(
		nested_44c_anchors.size() == 1
		and int(nested_44c_anchors[0].offset) == 0xC52A
		and nested_44c_anchors[0].event_start_kind == "audited_nested_promise"
		and nested_hotel_anchors.size() == 1
		and int(nested_hotel_anchors[0].offset) == 0x421C
		and nested_hotel_anchors[0].event_start_kind == "audited_nested_promise",
		"Event Player exposes only the two hash-bound L_TALK30 caller starts"
	)
	_check(
		(player._confirmed_preview_anchors("44C.MES", "00") as Array).is_empty()
		and (player._confirmed_preview_anchors("L_HOTEL2.MES", "00") as Array).is_empty(),
		"Event Player hides nested PROMIS starts when either caller hash differs"
	)
	var promise_anchors: Array = player._confirmed_preview_anchors("A_PROMIS.MES", "81d3de790b2a1542f09dfedd753c5010970971acb38e64b9e0241c6c2f31ca19")
	_check(
		promise_anchors.size() == 1
		and int(promise_anchors[0].offset) == 0x2036
		and promise_anchors[0].event_start_kind == "isolated_promise_date"
		and int(promise_anchors[0].boundary) == 0x2091
		and int(promise_anchors[0].resume) == 0x2096
		and int(promise_anchors[0].writer) == 0x209B
		# Core 0.316.0 (2026-09-13): the date suffix runs to the choice boundary; the
		# anchor carries its row count instead of a fake return coordinate.
		and int(promise_anchors[0].date_suffix_rows) == 103
		and int(promise_anchors[0].field) == 215,
		"Event Player exposes the hash-bound A_PROMIS isolated routine-24 date route"
	)
	_check(
		(player._confirmed_preview_anchors("A_PROMIS.MES", "00") as Array).is_empty(),
		"Event Player hides the PROMIS date route when its resolved MES hash differs"
	)
	var c_promise_anchors: Array = player._confirmed_preview_anchors("C_PROMIS.MES", "485e997c7c328277de5dbdd11f32bcff291a20005825a26d5aecfbc172eb3fba")
	_check(
		c_promise_anchors.size() == 1
		and int(c_promise_anchors[0].offset) == 0x1B97
		and int(c_promise_anchors[0].boundary) == 0x1C0B
		and int(c_promise_anchors[0].writer) == 0x1C15
		and int(c_promise_anchors[0].choice_boundary) == 0x2655
		and int(c_promise_anchors[0].location_field) == 169
		and str(c_promise_anchors[0].validation_mode) == "presentation_to_choice"
		and not c_promise_anchors[0].has("date_probe_return"),
		"Event Player exposes the presentation-bearing C_PROMIS scheduling route without inventing an intermediate return"
	)
	var eventd05_anchors: Array = player._confirmed_preview_anchors("EVENTD05.MES", "525dbd286ea252232dbda6511c0fa3091315a77b20a838c0ec0576a33717b335")
	_check(eventd05_anchors.size() == 1 and int(eventd05_anchors[0].offset) == 0 and eventd05_anchors[0].prelude_mmo_route == "eventd05_hhmm" and eventd05_anchors[0].event_start_kind == "dialogue", "EVENTD05 exposes its hash-bound complete dialogue/choice start and time-routed frame context")
	_check((player._confirmed_preview_anchors("EVENTD05.MES", "00") as Array).is_empty(), "Event Player hides the EVENTD05 start when its resolved MES hash differs")
	_check(str(KakyuEventPlayerRules.eventd05_background_specification(0).resource) == "D05Z.MMO" and int(KakyuEventPlayerRules.eventd05_background_specification(0).source_offset) == 0x1BD, "EVENTD05 before-0600 frame selects its original Z reference")
	_check(str(KakyuEventPlayerRules.eventd05_background_specification(600).resource) == "D05X.MMO" and int(KakyuEventPlayerRules.eventd05_background_specification(600).source_offset) == 0x1DC, "EVENTD05 0600 frame selects its first original X reference")
	_check(str(KakyuEventPlayerRules.eventd05_background_specification(900).resource) == "D05X.MMO" and int(KakyuEventPlayerRules.eventd05_background_specification(900).source_offset) == 0x1FB, "EVENTD05 0900 frame selects its second original X reference")
	_check(str(KakyuEventPlayerRules.eventd05_background_specification(1600).resource) == "D05Y.MMO", "EVENTD05 1600 frame selects its original Y reference")
	_check(str(KakyuEventPlayerRules.eventd05_background_specification(1800).resource) == "D05Z.MMO" and int(KakyuEventPlayerRules.eventd05_background_specification(1800).source_offset) == 0x22D, "EVENTD05 1800 frame returns to its original Z reference")
	var eventd08_anchors: Array = player._confirmed_preview_anchors("EVENTD08.MES", "add5a481c407c863b646799d961033c5ce62da1b1874c227fd41d5685e7fd31c")
	_check(
		eventd08_anchors.size() == 1
		and int(eventd08_anchors[0].offset) == 0
		and eventd08_anchors[0].event_start_kind == "dialogue"
		and not eventd08_anchors[0].has("prelude_mmo")
		and eventd08_anchors[0].prelude_bgm == "MAKI.WAV"
		and int(eventd08_anchors[0].prelude_bgm_selector) == 33
		and int(eventd08_anchors[0].prelude_bgm_offset) == 0x009A
		and int(eventd08_anchors[0].prelude_bgm_boundary) == 0x00A0
		and int(eventd08_anchors[0].prelude_bgm_routine) == 23
		and eventd08_anchors[0].prelude_bgm_entry == "D_PIC.MES",
		"Event Player exposes EVENTD08's hash-bound zero-coordinate dialogue start with inherited BGM but no premature MMO frame"
	)
	_check((player._confirmed_preview_anchors("EVENTD08.MES", "00") as Array).is_empty(), "Event Player hides the EVENTD08 zero-start when its resolved MES hash differs")
	var eventd06_catalog: Dictionary = player._confirmed_address_catalog("EVENTD06.MES", "ce90c77ca8ca6dae38b236eb5dfc19ef1848083b433d86d9f49331968769c142")
	var eventd14_catalog: Dictionary = player._confirmed_address_catalog("EVENTD14.MES", "4279a51fc9510d2442b537b9cf28613074da000d35c3c72ba9758dae63e1b24f")
	_check(
		int(eventd06_catalog.entry_count) == 67
		and eventd06_catalog.caller_entry == "10C.MES"
		and int(eventd06_catalog.caller_offset) == 0x5F77
		and int(eventd06_catalog.caller_command) == 0x0E
		and int(eventd06_catalog.setup_start_coordinate) == 0x0008
		and int(eventd06_catalog.setup_entry_offset) == 0x0008
		and eventd06_catalog.setup_start_kind == "source_table_entry"
		and eventd06_catalog.setup_mmo_followup_write == {"offset": 0x022D, "bank": 0, "index": 1, "value": 7}
		# Core 0.316.0 (2026-09-13): the setup runs through the omitted call at 0x0B52
		# to its extension terminal.
		and eventd06_catalog.setup_terminal_status == "shared_routine_boundary"
		and int(eventd06_catalog.setup_terminal_offset) == 0x0C0E
		and int(eventd06_catalog.setup_terminal_message_count) == 0
		and eventd06_catalog.setup_extension_mmo == "D07.MMO"
		and eventd06_catalog.setup_extension_terminals == [
			{"status": "shared_routine_boundary", "offset": 0x0C0E, "resume": 0x0C13, "routine_id": 21, "branch_global_u8_4000": 0},
			{"status": "shared_routine_boundary", "offset": 0x0C1E, "resume": 0x0C23, "routine_id": 28, "branch_global_u8_4000": 1},
		]
		and eventd06_catalog.exe_audit_schema == "kakyu_ai5_mes_exe_audit/v106",
		"Event Player binds EVENTD06 setup analysis to its original source-table entry and unresolved 10C handoff"
	)
	_check(
		int(eventd14_catalog.entry_count) == 66
		and eventd14_catalog.caller_entry == "12C.MES"
		and int(eventd14_catalog.caller_offset) == 0x1C23
		and int(eventd14_catalog.caller_command) == 0x0F
		and int(eventd14_catalog.setup_start_coordinate) == 0
		and int(eventd14_catalog.setup_entry_offset) == 0x0008
		and eventd14_catalog.setup_start_kind == "audited_nested_call"
		and int(eventd14_catalog.nested_start_coordinate) == 0
		and int(eventd14_catalog.bootstrap_target) == 0x0008
		and int(eventd14_catalog.bootstrap_entry_index) == 0
		and bool(eventd14_catalog.setup_reaches_event_choice)
		and eventd14_catalog.setup_terminal_status == "def_selection_boundary"
		and int(eventd14_catalog.setup_terminal_offset) == 0x0942
		and eventd14_catalog.route_terminal_status == "script_return"
		and int(eventd14_catalog.route_terminal_offset) == 0x256D
		and int(eventd14_catalog.route_completion_state_index) == 763
		and eventd14_catalog.exe_audit_schema == "kakyu_ai5_mes_exe_audit/v106",
		"Event Player binds EVENTD14 to its audited 12C zero-start dispatch and confirmed route terminal"
	)
	var saved_document: Dictionary = player.get("_document")
	var source_setup_code := PackedByteArray([0x14, 0x01, 0xFF, 0x08, 0x00, 0x00, 0x00, 0xFF, 0x17, 0x00, 0x00, 0x00, 0x00])
	player.set("_document", {
		"bytecode": source_setup_code,
		"header": {"code_size": source_setup_code.size()},
		"entries": [{"index": 0, "offset": 8, "end_offset": source_setup_code.size()}],
	})
	var source_setup_validation: Dictionary = player._validate_catalog_bootstrap(eventd06_catalog,
		MesInstructionDecoderScript.new()
	)
	_check(
		source_setup_validation.get("ok", false)
		and int(source_setup_validation.setup_start_coordinate) == 8
		and source_setup_validation.setup_start_kind == "source_table_entry",
		"Event Player accepts only the verified EVENTD06 source-table setup entry for isolated analysis"
	)
	var shifted_source_setup: Dictionary = eventd06_catalog.duplicate(true)
	shifted_source_setup["setup_start_coordinate"] = 9
	_check(
		not (player._validate_catalog_bootstrap(shifted_source_setup, MesInstructionDecoderScript.new()) as Dictionary).get("ok", false),
		"Event Player rejects a shifted EVENTD06 source-table setup start"
	)
	var bootstrap_code := PackedByteArray([0x14, 0x01, 0xFF, 0x08, 0x00, 0x00, 0x00, 0xFF, 0x17, 0x00, 0x00, 0x00, 0x00])
	player.set("_document", {
		"bytecode": bootstrap_code,
		"header": {"code_size": bootstrap_code.size()},
		"entries": [{"index": 0, "offset": 8, "end_offset": bootstrap_code.size()}],
	})
	var bootstrap_validation: Dictionary = player._validate_catalog_bootstrap(eventd14_catalog,
		MesInstructionDecoderScript.new()
	)
	_check(
		bootstrap_validation.get("ok", false)
		and int(bootstrap_validation.nested_start_coordinate) == 0
		and int(bootstrap_validation.bootstrap_target) == 8,
		"Event Player accepts the exact zero-start bootstrap into catalog setup"
	)
	bootstrap_code[3] = 0x09
	player.set("_document", {
		"bytecode": bootstrap_code,
		"header": {"code_size": bootstrap_code.size()},
		"entries": [{"index": 0, "offset": 8, "end_offset": bootstrap_code.size()}],
	})
	_check(
		not (player._validate_catalog_bootstrap(eventd14_catalog, MesInstructionDecoderScript.new()) as Dictionary).get("ok", false),
		"Event Player fails closed when the catalog bootstrap target changes"
	)
	player.set("_document", saved_document)
	_check(
		(player._confirmed_address_catalog("EVENTD06.MES", "00") as Dictionary).is_empty(),
		"Event Player hides a catalog when its resolved MES hash differs"
	)
	var address_tree: Tree = player.get_node("Margin/Layout/MainSplit/Sources/AddressTree")
	var preview_fragment_button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/PreviewFragment")
	var previous_fragment_button: Button = player.get_node("Margin/Layout/MainSplit/Sources/FragmentNavigation/PreviousFragment")
	var next_fragment_button: Button = player.get_node("Margin/Layout/MainSplit/Sources/FragmentNavigation/NextFragment")
	var previous_meaningful_button: Button = player.get_node("Margin/Layout/MainSplit/Sources/MeaningfulNavigation/PreviousMeaningful")
	var next_meaningful_button: Button = player.get_node("Margin/Layout/MainSplit/Sources/MeaningfulNavigation/NextMeaningful")
	var source_row_code := PackedByteArray([0x01, 0x41, 0x00, 0x00])
	var source_row_offsets: Array[int] = [0]
	var source_row_entries: Array[Dictionary] = [
		{"index": 0, "offset": 0, "end_offset": source_row_code.size()},
	]
	for row_index in range(1, 19):
		var row_offset := source_row_code.size()
		source_row_offsets.append(row_offset)
		source_row_code.append(0x00)
		source_row_entries.append({
			"index": row_index,
			"offset": row_offset,
			"end_offset": source_row_code.size(),
		})
	var final_source_row_index := source_row_entries.size()
	var final_source_row_offset := source_row_code.size()
	source_row_offsets.append(final_source_row_offset)
	source_row_code.append_array(PackedByteArray([0x01, 0x42, 0x00, 0x00]))
	source_row_entries.append({
		"index": final_source_row_index,
		"offset": final_source_row_offset,
		"end_offset": source_row_code.size(),
	})
	player.set("_selected_entry", "GENERIC.MES")
	player.set("_active_address_catalog", {})
	player.set("_document", {
		"ok": true,
		"bytecode": source_row_code,
		"header": {"code_size": source_row_code.size(), "entry_offsets": source_row_offsets},
		"entries": source_row_entries,
	})
	address_tree.clear()
	var source_root := address_tree.create_item()
	var source_item: TreeItem
	for entry in source_row_entries:
		var added_item: TreeItem = player._add_address(source_root,
			"#%04d" % int(entry.index),
			int(entry.offset),
			int(entry.end_offset),
			"address_entry",
			int(entry.index)
		)
		if int(entry.index) == 0:
			source_item = added_item
	var source_row_state_before: Dictionary = (player.get("_state") as KakyuMesSandboxState).snapshot()
	source_item.select(0)
	player.select_address()
	_check(
		not preview_fragment_button.disabled
		and preview_fragment_button.text == "Preview Row #0000"
		and preview_fragment_button.tooltip_text.contains("not a confirmed native host selection")
		and source_item.get_text(2) == "4 · 1 msg"
		and source_item.get_tooltip_text(2).contains("First isolated stop: script_return")
		and previous_fragment_button.disabled
		and not next_fragment_button.disabled
		and previous_meaningful_button.disabled
		and not next_meaningful_button.disabled
		and (player.get("_state") as KakyuMesSandboxState).snapshot() == source_row_state_before,
		"Event Player exposes an ordinary address row with a non-mutating first-stop summary"
	)
	player._on_address_activated()
	_check(
		str(player.get("_preview_event_session")) == "source_row"
		and (player.get("_preview_messages") as Array).size() == 1
		and str((player.get("_preview_messages") as Array)[0].text) == "A"
		and str((player.get("_preview_entry_label") as Label).text).contains("source row #0000")
		and str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("native host selection/order not inferred"),
		"double-click previews an ordinary source-table row without presenting it as an event start"
	)
	_check(
		KakyuEventPlayerRules.source_row_is_meaningful({"message_count": 1})
		and KakyuEventPlayerRules.source_row_is_meaningful({"definition_count": 1})
		and KakyuEventPlayerRules.source_row_is_meaningful({"status": "native_presentation_boundary"})
		and not KakyuEventPlayerRules.source_row_is_meaningful({"status": "script_return"})
		and not KakyuEventPlayerRules.source_row_is_meaningful({"status": "script_return", "state_diff_count": 2})
		and not KakyuEventPlayerRules.source_row_is_meaningful({"status": "unsupported_opcode"}),
		"content-row navigation classifies dialogue, DEF, and native FX without promoting an empty return"
	)
	player._on_next_meaningful_row_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 16
		and int(player.get("_preview_source_row_index")) == 0
		and str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("Scanned 16")
		and source_root.get_child(1).get_text(2) == "1 · return",
		"Next hit bounds a no-hit search to 16 rows and advances its visible cursor"
	)
	player._on_next_meaningful_row_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == final_source_row_index
		and int(player.get("_preview_source_row_index")) == final_source_row_index
		and str((player.get("_preview_messages") as Array)[0].text) == "B",
		"repeating Next hit skips the remaining empty returns and previews the next dialogue row"
	)
	player._on_previous_meaningful_row_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 3
		and int(player.get("_preview_source_row_index")) == final_source_row_index
		and str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("Scanned 16"),
		"Prev hit also bounds a no-hit reverse search and advances its visible cursor"
	)
	player._on_previous_meaningful_row_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 0
		and int(player.get("_preview_source_row_index")) == 0
		and str((player.get("_preview_messages") as Array)[0].text) == "A",
		"repeating Prev hit returns to the previous dialogue row in displayed table order"
	)
	player._on_next_catalog_fragment_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 1
		and int(player.get("_preview_source_row_index")) == 1
		and (player.get("_preview_messages") as Array).is_empty()
		and str(player.get("_preview_result_status")) == "script_return"
		and not previous_fragment_button.disabled
		and not next_fragment_button.disabled,
		"Next Row previews an adjacent empty-return row without claiming native event order"
	)
	player._on_previous_catalog_fragment_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 0
		and int(player.get("_preview_source_row_index")) == 0,
		"Prev Row returns to the prior ordinary source-table row"
	)
	var catalog_code := PackedByteArray([
		0x17, 0x00, 0x00, 0x00, 0x00,
		0x17, 0x01, 0x00, 0x00, 0x00,
		0x01, 0x41, 0x00,
		0x00,
		0x17, 0x02, 0x00, 0x00, 0x00,
		0x01, 0x42, 0x00,
		0x00,
	])
	player.set("_selected_entry", "EVENTD06.MES")
	player.set("_active_address_catalog", {"ok": true, "fragment_count": 2})
	player.set("_document", {
		"ok": true,
		"bytecode": catalog_code,
		"header": {"code_size": catalog_code.size(), "entry_offsets": [0, 5, 14]},
		"entries": [
			{"index": 0, "offset": 0, "end_offset": 5},
			{"index": 1, "offset": 5, "end_offset": 14},
			{"index": 2, "offset": 14, "end_offset": catalog_code.size()},
		],
	})
	var catalog_summaries: Dictionary = player._build_catalog_fragment_summaries()
	player.set("_catalog_fragment_summaries", catalog_summaries)
	_check(
		catalog_summaries.size() == 2
		and str(catalog_summaries[1].status) == "script_return"
		and int(catalog_summaries[1].message_count) == 1
		and int(catalog_summaries[1].state_diff_count) == 0
		and not catalog_summaries[1].has("text"),
		"Event Player derives lossless first-stop metadata without storing fragment dialogue in the catalog summary"
	)
	address_tree.clear()
	var catalog_root := address_tree.create_item()
	player._add_address(catalog_root, "Catalog setup #0000", 0, 5, "catalog_setup", 0)
	player._add_address(catalog_root, "Fragment #0001", 5, 14, "catalog_fragment", 1)
	player._add_address(catalog_root, "Fragment #0002", 14, catalog_code.size(), "catalog_fragment", 2)
	var fragment_item := catalog_root.get_child(1)
	fragment_item.select(0)
	player.select_address()
	_check(
		not preview_fragment_button.disabled
		and preview_fragment_button.text == "Preview #0001",
		"Event Player enables the dedicated preview action only for a selected catalog fragment"
	)
	_check(previous_fragment_button.disabled and not next_fragment_button.disabled, "catalog table navigation exposes only the available source-row direction")
	player._on_next_catalog_fragment_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 2
		and int(player.get("_preview_catalog_fragment_index")) == 2
		and (player.get("_preview_messages") as Array).size() == 1
		and str((player.get("_preview_messages") as Array)[0].text) == "B"
		and str((player.get("_preview_footer_label") as Label).text).contains("FRAGMENT END")
		and not previous_fragment_button.disabled
		and next_fragment_button.disabled,
		"Next Row previews the adjacent source-table fragment and labels its return as a fragment end"
	)
	player._on_previous_catalog_fragment_pressed()
	_check(
		int(address_tree.get_selected().get_metadata(2)) == 1
		and int(player.get("_preview_catalog_fragment_index")) == 1,
		"Prev Row returns to the prior source-table fragment without claiming native order"
	)
	player._on_preview_catalog_fragment_pressed()
	_check(
		str(player.get("_preview_result_status")) == "script_return"
		and (player.get("_preview_messages") as Array).size() == 1
		and str((player.get("_preview_entry_label") as Label).text).contains("fragment #0001")
		and str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("host selection order unresolved"),
		"Event Player previews a selected fragment in the game frame while keeping host order outside it"
	)
	var setup_code := PackedByteArray([
		0x14, 0x01, 0xFF, 0x08, 0x00, 0x00, 0x00, 0xFF,
		0x17, 0x00, 0x00, 0x00, 0x00,
		0x1D, 0x02, 0x1C, 0xFF, 0x00,
	])
	player.set("_selected_entry", "EVENTD14.MES")
	player.set("_active_address_catalog", {
		"ok": true,
		"fragment_count": 65,
		"setup_start_coordinate": 0,
		"setup_entry_offset": 8,
		"setup_entry_index": 0,
		"setup_start_kind": "audited_nested_call",
		"nested_start_coordinate": 0,
		"bootstrap_target": 8,
		"bootstrap_entry_index": 0,
		"setup_native_offset": 0x016C,
		"setup_native_resume": 0x0177,
		"setup_native_record_count": 3,
		"setup_reaches_event_choice": true,
		"setup_terminal_status": "def_selection_boundary",
		"setup_terminal_offset": 0x0942,
	})
	player.set("_document", {
		"ok": true,
		"entry_sha256": "4279a51fc9510d2442b537b9cf28613074da000d35c3c72ba9758dae63e1b24f",
		"source": {"resolved_source": "original_arc"},
		"bytecode": setup_code,
		"header": {"code_size": setup_code.size(), "entry_offsets": [8]},
		"entries": [{"index": 0, "offset": 8, "end_offset": setup_code.size()}],
	})
	address_tree.clear()
	var setup_root := address_tree.create_item()
	var setup_item: TreeItem = player._add_address(setup_root,
		"Catalog setup #0000",
		8,
		setup_code.size(),
		"catalog_setup",
		0
	)
	setup_item.select(0)
	player.select_address()
	_check(
		not preview_fragment_button.disabled
		and preview_fragment_button.text == "Start Confirmed Event"
		and previous_fragment_button.disabled
		and next_fragment_button.disabled,
		"Event Player exposes the audited EVENTD14 zero-start event without fragment navigation"
	)
	player._on_preview_catalog_fragment_pressed()
	var setup_trace_root := (player.get("trace_tree") as Tree).get_root()
	_check(
		str(player.get("_preview_event_session")) == "catalog_setup"
		and int(player.get("_preview_catalog_fragment_index")) == 0
		and str(player.get("_preview_result_status")) == "shared_routine_boundary"
		and str(player.get("_preview_entry_label").text).contains(" · confirmed event bootstrap · ")
		and setup_trace_root != null
		and setup_trace_root.get_child_count() >= 1
		and setup_trace_root.get_child(0).get_text(3).contains("bootstrap_transfer")
		and str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("confirmed dialogue/choice"),
		"Event Player runs the confirmed event bootstrap from code coordinate zero"
	)
	var catalog_native_result := {
		"status": "native_record_boundary",
		"offset": 0x016C,
		"command_id": 0x12,
		"trace": [{
			"command_id": 0x12,
			"source_offset": 0x016C,
			"end_offset": 0x0177,
			"effect": "native_record_boundary",
			"native_record_consumption": "typed_record_list_until_zero",
			"native_record_count": 3,
			"native_record_terminator_consumed": true,
		}],
	}
	_check(
		int(player._catalog_setup_native_stream_resume(catalog_native_result)) == 0x0177,
		"Event Player accepts only the hash-bound EVENTD14 setup record resume"
	)
	var changed_catalog_native_result: Dictionary = catalog_native_result.duplicate(true)
	changed_catalog_native_result["offset"] = 0x016D
	_check(
		int(player._catalog_setup_native_stream_resume(changed_catalog_native_result)) == -1,
		"Event Player rejects a shifted catalog setup presentation boundary"
	)
	player._capture_continuation(changed_catalog_native_result)
	_check(
		int(player.get("_continuation_offset")) == -1
		and (player.get_node("Margin/Layout/MainSplit/Right/RunBar/Continue") as Button).disabled,
		"Catalog setup cannot fall through to the generic native-presentation continuation"
	)
	player._capture_continuation(catalog_native_result)
	_check(
		int(player.get("_continuation_offset")) == 0x0177
		and str((player.get("_continuation_context") as Dictionary).get("kind", "")) == "catalog_setup_native_records_omitted"
		and str((player.get("_continuation_context") as Dictionary).get("native_record_policy", "")) == "omit_bounded"
		and (player.get_node("Margin/Layout/MainSplit/Right/RunBar/Continue") as Button).text == "Continue (Omit Setup Records)",
		"Event Player exposes the exact setup-only omission action"
	)
	var eventd14_setup_document: Dictionary = (player.get("_document") as Dictionary).duplicate(true)
	var eventd14_setup_catalog: Dictionary = (player.get("_active_address_catalog") as Dictionary).duplicate(true)
	player.set("_selected_entry", "EVENTD06.MES")
	player.set("_preview_event_session", "catalog_setup")
	var eventd06_active_catalog: Dictionary = eventd06_catalog.duplicate(true)
	eventd06_active_catalog["ok"] = true
	player.set("_active_address_catalog", eventd06_active_catalog)
	player.set("_document", {
		"ok": true,
		"entry_sha256": "ce90c77ca8ca6dae38b236eb5dfc19ef1848083b433d86d9f49331968769c142",
		"source": {"resolved_source": "original_arc"},
		"header": {"code_size": 0x26A4},
	})
	player._sync_event_start_button()
	_check(
		(player.get("start_event_button") as Button).disabled
		and (player.get("start_event_button") as Button).text == "Start Event"
		and (player.get("start_event_button") as Button).tooltip_text.contains("native host selection is unresolved"),
		"EVENTD06 exact setup continuation does not promote its unresolved catalog to Start Event"
	)
	# Core 0.316.0 (2026-09-13): the EVENTD06 setup declares no native presentation
	# boundary any more - the record at 0x0B52 is System.function[12](30), an
	# omitted call - so the setup surface resume accepts nothing.
	var eventd06_surface_boundary := {
		"status": "native_presentation_boundary",
		"offset": 0x0B52,
		"command_id": 0x0D,
		"argument_slots": {1: 7},
		"persistent_expression_stack": [3],
		"trace": [{"command_id": 0x0D, "source_offset": 0x0B52, "effect": "native_presentation_boundary"}],
	}
	_check(
		int(player._catalog_setup_native_stream_resume(eventd06_surface_boundary)) == -1,
		"EVENTD06 setup declares no native presentation boundary to resume from"
	)
	player._capture_continuation(eventd06_surface_boundary)
	_check(
		int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 setup cannot use generic fallthrough after a native boundary it no longer declares"
	)
	var library_index_before_eventd06_terminal: Dictionary = player.get("_library_index")
	player.set("_library_index", {
		"source": "synthetic terminal test",
		"by_id": {
			21: {"body_offset": 0x100, "end_offset": 0x110},
			28: {"body_offset": 0x200, "end_offset": 0x210},
		},
	})
	var eventd06_default_terminal := {
		"status": "shared_routine_boundary",
		"offset": 0x0C0E,
		"resume_offset": 0x0C13,
		"trace": [{"command_id": 0x1D, "source_offset": 0x0C0E, "routine_id": 21}],
	}
	var default_terminal_match: Dictionary = player._catalog_setup_extension_terminal(eventd06_default_terminal)
	player._capture_continuation(eventd06_default_terminal)
	_check(
		int(default_terminal_match.get("routine_id", -1)) == 21
		and int(default_terminal_match.get("branch_global_u8_4000", -1)) == 0
		and str(default_terminal_match.get("mmo", "")) == "D07.MMO"
		and int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 default setup extension stops safely at routine 21 after D07.MMO"
	)
	(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", 4000, 1)
	var eventd06_alternate_terminal := {
		"status": "shared_routine_boundary",
		"offset": 0x0C1E,
		"resume_offset": 0x0C23,
		"trace": [{"command_id": 0x1D, "source_offset": 0x0C1E, "routine_id": 28}],
	}
	var alternate_terminal_match: Dictionary = player._catalog_setup_extension_terminal(eventd06_alternate_terminal)
	player._capture_continuation(eventd06_alternate_terminal)
	_check(
		int(alternate_terminal_match.get("routine_id", -1)) == 28
		and int(alternate_terminal_match.get("branch_global_u8_4000", -1)) == 1
		and int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 global_u8[4000]=1 branch stops safely at its alternate routine 28 terminal"
	)
	var shifted_eventd06_terminal: Dictionary = eventd06_alternate_terminal.duplicate(true)
	shifted_eventd06_terminal["resume_offset"] = 0x0C24
	player._capture_continuation(shifted_eventd06_terminal)
	_check(
		(player._catalog_setup_extension_terminal(shifted_eventd06_terminal) as Dictionary).is_empty()
		and int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 setup extension rejects a shifted terminal resume without falling through to a shared-routine continuation"
	)
	(player.get("_preview_messages") as Array).clear()
	player._present_preview_result(shifted_eventd06_terminal, 0x0B88)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("Stopped fail-closed")
		and (player.get("_preview_footer_label") as Label).text.contains("terminal coordinate/resume/state/trace mismatch")
		and not (player.get("_preview_footer_label") as Label).text.contains("click / Space")
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 setup terminal mismatch presents a fail-closed diagnostic without a false Continue hint"
	)
	var shifted_offset_eventd06_terminal: Dictionary = eventd06_alternate_terminal.duplicate(true)
	shifted_offset_eventd06_terminal["offset"] = 0x0C1F
	shifted_offset_eventd06_terminal["resume_offset"] = 0x0C24
	shifted_offset_eventd06_terminal.trace = [
		{"command_id": 0x0D, "source_offset": 0x0BA2, "effect": "mmo_resource_marker", "resource_name": "D07.MMO"},
		{"command_id": 0x1D, "source_offset": 0x0C1F, "routine_id": 28, "effect": "shared_routine_call"},
	]
	player.set("_preview_catalog_setup_native_fx_omitted", true)
	player._capture_continuation(shifted_offset_eventd06_terminal)
	_check(
		int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 post-D07 shifted terminal also fails closed instead of enabling a generic shared-routine continuation"
	)
	var wrong_branch_eventd06_terminal: Dictionary = eventd06_default_terminal.duplicate(true)
	player._capture_continuation(wrong_branch_eventd06_terminal)
	_check(
		(player._catalog_setup_extension_terminal(wrong_branch_eventd06_terminal) as Dictionary).is_empty()
		and int(player.get("_continuation_offset")) == -1
		and (player.get("continue_button") as Button).disabled,
		"EVENTD06 setup extension rejects a mismatched branch state without falling through to a shared-routine continuation"
	)
	(player.get("_state") as KakyuMesSandboxState).write_value("global_u8", 4000, 0)
	player.set("_library_index", library_index_before_eventd06_terminal)
	player.set("_active_address_catalog", {})
	player._sync_catalog_preview_button()
	_check(
		preview_fragment_button.disabled and previous_fragment_button.disabled and next_fragment_button.disabled,
		"Event Player disables fragment browsing outside a verified catalog"
	)
	var definition_code := PackedByteArray([
		0x10, 0x02, 0x00, 0xFF, 0x00, 13, 0, 0, 0,
		0x01, 0x41, 0x00, 0x00,
		0x10, 0x02, 0x02, 0xFF, 0x00, 26, 0, 0, 0,
		0x01, 0x42, 0x00, 0x00,
		0x1D, 0x02, 0x28, 0xFF, 0x00,
	])
	player.set("_document", {
		"bytecode": definition_code,
		"header": {"code_size": definition_code.size()},
		"source": {"resolved_source": "original_arc"},
	})
	var definition_result: Dictionary = player.get("_runner").run(definition_code, 0, player.get("_state"))
	player._show_result(definition_result, 0)
	var definition_message_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/MessageTree")
	var definition_summary: RichTextLabel = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/Output")
	_check(player.get("_preview_definitions").size() == 2 and definition_message_tree.get_root().get_child_count() == 2, "Event Player presents each bounded DEF body in the Messages result")
	_check(
		(player.get("_preview_message_label") as Label).text == "> 1. A\n  3. B"
		and (player.get("_preview_footer_label") as Label).text.contains("Explicit detached DEF preview")
		and str((player.get("_choice_projection") as Dictionary).get("kind", "")) == "detached_def_preview",
		"game frame offers ordered DEF bodies only as explicit detached tool previews"
	)
	_check(
		definition_summary.text.contains("Choice input provenance:")
		and definition_summary.text.contains("command-0x12 typed-record lists")
		and definition_summary.text.contains("visible choice is explicit tool input")
		and definition_summary.text.contains("one-based result and keyboard callback wiring are confirmed")
		and definition_summary.text.contains("mouse, cadence, presentation, and callback effects remain unresolved")
		and definition_summary.text.contains("Choice audit panel:")
		and definition_summary.text.contains("does not execute the routine")
		and not definition_summary.text.contains("Slot 18 native writer audit:"),
		"Event Player explains routine-40 choice provenance outside the game frame"
	)
	var selection_native_spans: Array = shared_tree.get_meta("native_dispatch_spans", [])
	_check(
		selection_native_spans.size() == 1
		and int(selection_native_spans[0].record_count) == 3
		and int(selection_native_spans[0].payload_byte_count) == 10
		and bool(selection_native_spans[0].terminator_consumed)
		and int(shared_tree.get_meta("routine_id", -1)) == 40
		and str(shared_tree.get_meta("panel_role", "")) == "choice_provenance"
		and str(shared_tree.get_meta("source", "")) == "resolved content"
		and (player.get("result_tabs") as TabContainer).get_tab_title(4) == "Routine 40 Audit"
		and shared_tree.get_root() != null
		and shared_tree.get_root().get_child_count() == 2
		and shared_tree.get_root().get_child(0).get_text(2).contains("typed records"),
		"Event Player exposes the audited choice routine in a dedicated result tab without executing it"
	)
	var detached_state_before: Dictionary = (player.get("_state") as KakyuMesSandboxState).snapshot()
	player.confirm_choice(0)
	_check(
		(player.get("_preview_message_label") as Label).text == "A"
		and (player.get("_preview_footer_label") as Label).text.contains("DETACHED DEF 1")
		and (player.get("_preview_footer_label") as Label).text.contains("COMPLETE")
		and int(player.get("_preview_detached_definition_id")) == 0
		and int(player.get("_continuation_offset")) == -1
		and (player.get("_choice_projection") as Dictionary).is_empty(),
		"explicit generic DEF selection previews its bounded original body without enabling caller continuation"
	)
	_check(
		(player.get("_state") as KakyuMesSandboxState).snapshot() == detached_state_before
		and definition_summary.text.contains("Detached DEF preview:")
		and definition_summary.text.contains("cloned sandbox discarded"),
		"detached DEF preview discards cloned sandbox effects and labels unresolved native mapping outside the frame"
	)
	var grouped_definition_code := PackedByteArray([
		0x1B, 0x02, 0x00, 0xFF, 0x00,
		0x10, 0x02, 0x00, 0xFF, 0x00, 18, 0, 0, 0,
		0x01, 0x41, 0x00, 0x00,
		0x10, 0x02, 0x01, 0xFF, 0x00, 39, 0, 0, 0,
		0x01, 0x42, 0x52, 0x41, 0x56, 0x4F, 0x2D, 0x54, 0x57, 0x4F, 0x00, 0x00,
		0x1B, 0x02, 0x01, 0xFF, 0x00,
		0x10, 0x02, 0x00, 0xFF, 0x00, 57, 0, 0, 0,
		0x01, 0x43, 0x00, 0x00,
		0x1B, 0x02, 0x02, 0xFF, 0x00,
		0x1D, 0x02, 0x28, 0xFF, 0x00,
	])
	_append_grouped_routine40_consumer(grouped_definition_code)
	var grouped_previous_entry = player.get("_selected_entry")
	var grouped_previous_document = player.get("_document")
	player.set("_selected_entry", "GROUPED.MES")
	var grouped_document := {
		"bytecode": grouped_definition_code,
		"entry_sha256": _sha256(grouped_definition_code),
		"header": {"code_size": grouped_definition_code.size()},
		"source": {"archive": "mes.arc", "resolved_source": "synthetic"},
	}
	player.set("_document", grouped_document)
	var grouped_definition_result: Dictionary = player.get("_runner").run(
		grouped_definition_code, 0, player.get("_state")
	)
	player._show_result(grouped_definition_result, 0)
	var grouped_state_before := (player.get("_state") as KakyuMesSandboxState).snapshot()
	_check(
		(player.get("_preview_definitions") as Array).size() == 2
		and (player.get("_preview_message_label") as Label).text == "> 1. A\n  2. BRAVO-TWO"
		and (player.get("_preview_footer_label") as Label).text.contains("Routine 40 grouped analysis")
		and (player.get("_preview_footer_label") as Label).text.contains("first-stage group 0")
		and (player.get("_preview_footer_label") as Label).text.contains("3 retained rows")
		and definition_summary.text.contains("Native DEF groups:")
		and definition_summary.text.contains("0:2, 1:1, 2:0")
		and definition_summary.text.contains("retained second-stage rows may be inspected only through a disposable analysis preview")
		and str((player.get("_choice_projection") as Dictionary).get("kind", "")) == "routine40_group_analysis_preview"
		and str((player.get("_choice_projection") as Dictionary).get("contract", {}).get("schema", ""))
			== ContentCoreVersionScript.MES_ROUTINE40_GROUP_PREVIEW_SCHEMA,
		"Event Player exposes fixed-key group 0 through a source-bound disposable grouped analysis contract"
	)
	player._move_confirmed_choice(-1)
	_check(
		(player.get("_preview_message_label") as Label).text.begins_with("> 1. A"),
		"grouped routine-40 analysis keeps original clamped non-wrapping row navigation"
	)
	player.confirm_choice(0)
	var grouped_consumer_plan: Dictionary = player._routine40_group_consumer_plan(player.get("_choice_projection"), 1
	)
	_check(
		(player.get("_preview_definitions") as Array).size() == 1
		and (player.get("_preview_message_label") as Label).text == "> 1. C"
		and (player.get("_preview_footer_label") as Label).text.contains("first result 1 -> group 1")
		and (player.get("_preview_footer_label") as Label).text.contains("consumer 0x")
		and str((player.get("_choice_projection") as Dictionary).get("stage", "")) == "second"
		and str(grouped_consumer_plan.get("schema", ""))
			== ContentCoreVersionScript.EVENT_PLAYER_ROUTINE40_CONSUMER_PLAN_SCHEMA
		and str(grouped_consumer_plan.get("route", {}).get("resolution", ""))
			== "stored_consumer_coordinate"
		and (player.get("_state") as KakyuMesSandboxState).snapshot() == grouped_state_before,
		"first-stage analysis selection opens only a source-qualified second-stage consumer plan without writing slot 21"
	)
	var changed_grouped_code := grouped_definition_code.duplicate()
	changed_grouped_code[10] ^= 0x01
	var changed_grouped_document := grouped_document.duplicate(true)
	changed_grouped_document.bytecode = changed_grouped_code
	player.set("_document", changed_grouped_document)
	_check(
		not (player._routine40_group_consumer_plan(player.get("_choice_projection"), 1
		) as Dictionary).get("ok", false)
		and (player.get("_state") as KakyuMesSandboxState).snapshot() == grouped_state_before,
		"grouped Analysis rejects changed bytes before accepting a consumer hint or mutating state"
	)
	player.set("_document", grouped_document)
	player.confirm_choice(0)
	_check(
		(player.get("_state") as KakyuMesSandboxState).snapshot() == grouped_state_before
		and (player.get("status_label") as Label).text.contains("result 1/1 in a cloned sandbox")
		and (player.get("_preview_footer_label") as Label).text.contains("caller dispatch not resumed"),
		"second-stage analysis inspects its retained body in a disposable sandbox without writing slot 13"
	)
	player._show_result(grouped_definition_result, 0)
	player._show_confirmed_choice_options()
	player.confirm_choice(1)
	_check(
		(player.get("_state") as KakyuMesSandboxState).snapshot() == grouped_state_before
		and (player.get("_preview_message_label") as Label).text.contains("empty group 2")
		and (player.get("_preview_message_label") as Label).text.contains("0xFFFF")
		and (player.get("_preview_footer_label") as Label).text.contains("post-return dispatch")
		and (player.get("_choice_projection") as Dictionary).is_empty(),
		"empty mapped groups require the source-qualified 0xFFFF plan and stop without caller resume"
	)
	player.set("_selected_entry", grouped_previous_entry)
	player.set("_document", grouped_previous_document)
	var bridge_code := _routine40_bridge_code()
	var bridge_state: KakyuMesSandboxState = player.get("_state")
	var bridge_state_before := bridge_state.snapshot()
	var bridge_previous_entry = player.get("_selected_entry")
	var bridge_previous_document = player.get("_document")
	player.set("_selected_entry", "BRIDGE.MES")
	player.set("_document", {
		"bytecode": bridge_code,
		"entry_sha256": _sha256(bridge_code),
		"header": {"code_size": bridge_code.size()},
		"source": {"archive": "mes.arc", "resolved_source": "synthetic"},
	})
	bridge_state.write_value("state_u16", 13, 0x1313)
	bridge_state.write_value("state_u16", 18, 0x1818)
	var bridge_boundary: Dictionary = player.get("_runner").run(
		bridge_code, 0, bridge_state, bridge_code.size()
	)
	player.set("_preview_event_session", "source_row")
	player._clear_continuation()
	player._show_result(bridge_boundary, 0)
	player._show_confirmed_choice_options()
	var source_row_projection: Dictionary = (player.get("_choice_projection") as Dictionary).duplicate(true)
	var bridge_source_row_state_before := bridge_state.snapshot()
	player.confirm_choice(1)
	_check(
		str(source_row_projection.get("kind", "")) == "detached_def_preview",
		"source-row analysis gives detached preview priority over an otherwise compatible routine-40 bridge"
	)
	_check(
		bridge_state.snapshot() == bridge_source_row_state_before,
		"source-row detached preview discards its cloned sandbox"
	)
	_check(
		int(player.get("_continuation_offset")) == -1,
		"source-row detached preview never enables caller continuation"
	)
	player.set("_preview_event_session", "")
	player._show_result(bridge_boundary, 0)
	player._show_confirmed_choice_options()
	var bridge_projection: Dictionary = player.get("_choice_projection")
	_check(
		str(bridge_projection.get("kind", "")) == "routine40_result_bridge"
		and str(bridge_projection.get("contract", {}).get("schema", ""))
			== ContentCoreVersionScript.MES_ROUTINE40_CHOICE_CONTRACT_SCHEMA
		and (player.get("_preview_message_label") as Label).text == "> 1. A\n  2. B\n  3. C"
		and (player.get("_preview_footer_label") as Label).text.contains("Routine 40 remake bridge")
		and (player.get("_preview_footer_label") as Label).text.contains("native helper input/effects unresolved"),
		"Event Player activates a source-bound generic routine-40 remake bridge only for an exact caller result chain"
	)
	player.confirm_choice(1)
	_check(
		bridge_state.read_value("state_u16", 21) == 2
		and bridge_state.read_value("state_u16", 18) == 0x1818
		and bridge_state.read_value("state_u16", 13) == 0x1313
		and definition_summary.text.contains("Routine 40 remake bridge:")
		and definition_summary.text.contains("explicit option 2 wrote caller-visible state_u16[21]")
		and definition_summary.text.contains("native helper input and omitted slot-18/slot-13/routine-20/vector effects remain unresolved")
		and (player.get("status_label") as Label).text.contains("resumed the exact MES consumer"),
		"generic routine-40 confirmation writes only the caller-visible result and resumes the original branch chain"
	)
	bridge_state.restore(bridge_state_before)
	var single_bridge_code := _routine40_single_bridge_code()
	player.set("_selected_entry", "SINGLE_BRIDGE.MES")
	player.set("_document", {
		"bytecode": single_bridge_code,
		"entry_sha256": _sha256(single_bridge_code),
		"header": {"code_size": single_bridge_code.size()},
		"source": {"archive": "mes.arc", "resolved_source": "synthetic"},
	})
	var single_bridge_boundary: Dictionary = player.get("_runner").run(
		single_bridge_code, 0, bridge_state, single_bridge_code.size()
	)
	player._show_result(single_bridge_boundary, 0)
	player._show_confirmed_choice_options()
	var single_bridge_projection: Dictionary = player.get("_choice_projection")
	_check(
		str(single_bridge_projection.get("kind", "")) == "routine40_result_bridge"
		and int(single_bridge_projection.get("contract", {}).get("definition_count", 0)) == 1
		and int((single_bridge_projection.get("contract", {}).get("definitions", []) as Array)[0].definition_id) == 2
		and (player.get("_preview_message_label") as Label).text == "> 1. ONLY",
		"Event Player numbers a source-bound single-row routine-40 bridge as option 1 despite its stored non-zero DEF ID"
	)
	player.confirm_choice(0)
	_check(
		bridge_state.read_value("state_u16", 21) == 1
		and definition_summary.text.contains("explicit option 1 wrote caller-visible state_u16[21]")
		and (player.get("status_label") as Label).text.contains("Routine 40 remake choice 1"),
		"single-row routine-40 confirmation writes only result 1 and resumes its exact original true branch"
	)
	bridge_state.restore(bridge_state_before)
	var gated_bridge_code := _routine40_gated_bridge_code()
	player.set("_selected_entry", "GATED_BRIDGE.MES")
	player.set("_document", {
		"bytecode": gated_bridge_code,
		"entry_sha256": _sha256(gated_bridge_code),
		"header": {"code_size": gated_bridge_code.size()},
		"source": {"archive": "mes.arc", "resolved_source": "synthetic"},
	})
	bridge_state.write_value("global_u8", 7, 1)
	var gated_boundary: Dictionary = player.get("_runner").run(
		gated_bridge_code, 0, bridge_state, gated_bridge_code.size()
	)
	player._show_result(gated_boundary, 0)
	player._show_confirmed_choice_options()
	var gated_projection: Dictionary = player.get("_choice_projection")
	_check(
		str(gated_projection.get("kind", "")) == "routine40_result_bridge"
		and str(gated_projection.get("contract", {}).get("consumer_kind", ""))
			== "gated_one_based_state_u16_21_branch_matrix"
		and int(gated_projection.get("gate_value", -1)) == 1
		and (player.get("_preview_footer_label") as Label).text.contains("preserve global_u8[7]=1"),
		"Event Player exposes a complete gated routine-40 matrix without changing its existing gate"
	)
	player.confirm_choice(1)
	_check(
		bridge_state.read_value("state_u16", 21) == 2
		and bridge_state.read_value("global_u8", 7) == 1
		and definition_summary.text.contains("preserved global_u8[7]=1")
		and (player.get("status_label") as Label).text.contains("preserving global_u8[7]=1"),
		"gated routine-40 confirmation writes only slot 21 and resumes under the preserved gate"
	)
	bridge_state.restore(bridge_state_before)
	bridge_state.write_value("global_u8", 7, 0)
	var changed_gate_boundary: Dictionary = player.get("_runner").run(
		gated_bridge_code, 0, bridge_state, gated_bridge_code.size()
	)
	player._show_result(changed_gate_boundary, 0)
	bridge_state.write_value("global_u8", 7, 1)
	var changed_gate_state := bridge_state.snapshot()
	player.confirm_choice(2)
	_check(
		bridge_state.snapshot() == changed_gate_state
		and (player.get("_choice_projection") as Dictionary).is_empty()
		and (player.get("status_label") as Label).text.contains("changed or unsupported result gate"),
		"gated routine-40 confirmation rejects a changed gate before writing slot 21"
	)
	bridge_state.restore(bridge_state_before)
	player.set("_selected_entry", "BRIDGE.MES")
	player.set("_document", {
		"bytecode": bridge_code,
		"entry_sha256": _sha256(bridge_code),
		"header": {"code_size": bridge_code.size()},
		"source": {"archive": "mes.arc", "resolved_source": "synthetic"},
	})
	var stale_boundary: Dictionary = player.get("_runner").run(
		bridge_code, 0, bridge_state, bridge_code.size()
	)
	player._show_result(stale_boundary, 0)
	var stale_state_before := bridge_state.snapshot()
	var changed_bridge_code := bridge_code.duplicate()
	changed_bridge_code[1] ^= 0x01
	(player.get("_document") as Dictionary).bytecode = changed_bridge_code
	player.confirm_choice(2)
	_check(
		bridge_state.snapshot() == stale_state_before
		and (player.get("_choice_projection") as Dictionary).is_empty()
		and (player.get("status_label") as Label).text.contains("rejected a changed source or result consumer before state mutation"),
		"generic routine-40 confirmation rejects stale bytecode before mutating caller-visible state"
	)
	bridge_state.restore(bridge_state_before)
	player.set("_selected_entry", bridge_previous_entry)
	player.set("_document", bridge_previous_document)
	var ten_choices: Array[Dictionary] = []
	for choice_index in range(10):
		ten_choices.append({
			"definition_id": choice_index,
			"source_offset": choice_index,
			"target_offset": choice_index + 1,
			"text": "option %d" % (choice_index + 1),
		})
	var before_promise_matrix_entry = player.get("_selected_entry")
	var before_promise_matrix_document = player.get("_document")
	player.set("_selected_entry", "B_PROMIS.MES")
	player.set("_document", {
		"entry_sha256": "c1270051a6ea49bcc84fae4d9060e6d2bc114b672dc8beecdf5e97dc552c446d",
		"source": {"resolved_source": "original_arc"},
	})
	(player.get("_state") as RefCounted).call("write_value", "global_u8", 209, 2)
	player.set("_preview_definitions", ten_choices)
	player.set("_choice_projection", {"kind": "promise_time", "state_index": 21})
	player.set("_choice_index", 0)
	player._show_confirmed_choice_options()
	_check(
		(player.get("_preview_message_label") as Label).text.split("\n").size() == 3
		and (player.get("_preview_message_label") as Label).text.contains("> 1. option 1 [OK]")
		and (player.get("_preview_footer_label") as Label).text.contains("option 1/10")
		and (player.get("_preview_footer_label") as Label).text.contains("L2: OK/NO/GATE")
		and (player.get("_preview_footer_label") as Label).text.contains("1-9/0"),
		"Event Player pages a ten-option PROMIS choice with its audited location status"
	)
	player._move_confirmed_choice(-1)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("> 10. option 10 [OK]")
		and (player.get("_preview_footer_label") as Label).text.contains("option 10/10"),
		"Event Player keyboard choice navigation wraps through all ten PROMIS time options"
	)
	_check(
		str(KakyuEventPlayerRules.promise_option_route_state(1, "B_PROMIS.MES", 0, 0)) == "rejected"
		and str(KakyuEventPlayerRules.promise_option_route_state(10, "B_PROMIS.MES", 0, 0)) == "allowed"
		and str(KakyuEventPlayerRules.promise_option_route_state(10, "B_PROMIS.MES", 1, 0)) == "rejected"
		and str(KakyuEventPlayerRules.promise_option_route_state(8, "A_PROMIS.MES", 2, 0)) == "entry_gate"
		and str(KakyuEventPlayerRules.promise_option_route_state(8, "A_PROMIS.MES", 2, 1)) == "allowed",
		"Event Player keeps the audited time/location matrix and A evening latch gate distinct"
	)
	player._clear_choice_projection()
	player.set("_preview_definitions", [])
	player.set("_selected_entry", before_promise_matrix_entry)
	player.set("_document", before_promise_matrix_document)
	var native_selection_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x15, 0x01, 0x41, 0x00, 0x02, 0x05, 0xFF, 0x00]),
		0,
		player.get("_state")
	)
	player._show_result(native_selection_result, 0)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("Native selection input reached")
		and (player.get("_preview_footer_label") as Label).text.contains("2 records")
		and native_selection_result.state_diff.is_empty(),
		"Event Player labels command 0x15 as an unresolved native input boundary without changing the sandbox"
	)
	var definition_invoke_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x11, 0x02, 0x29, 0xFF, 0x00, 0x00]),
		0,
		player.get("_state")
	)
	player._show_result(definition_invoke_result, 0)
	var definition_trace_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/TraceTree")
	_check(
		definition_trace_tree.get_root().get_child(0).get_text(3).contains("def=41"),
		"Event Player trace shows the evaluated command 0x11 DEF selector"
	)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("Native registered DEF invocation reached")
		and (player.get("_preview_footer_label") as Label).text.contains("DEF 41")
		and definition_invoke_result.state_diff.is_empty(),
		"Event Player explains the command 0x11 caller-frame boundary without changing the sandbox"
	)
	var inline_script_code := PackedByteArray([0x0D, 0x08, 0xFF, 0x02, 0x03, 0xFF, 0x01])
	inline_script_code.append_array("def_main.mes".to_ascii_buffer())
	inline_script_code.append_array(PackedByteArray([0x00, 0x00, 0x00]))
	var inline_script_result: Dictionary = player.get("_runner").run(
		inline_script_code,
		0,
		player.get("_state")
	)
	player._show_result(inline_script_result, 0)
	var inline_script_trace_text := definition_trace_tree.get_root().get_child(0).get_text(3)
	_check(
		inline_script_trace_text.contains("DEF_MAIN.MES")
		and inline_script_trace_text.contains("selector=3")
		and inline_script_trace_text.contains("role=definition_bootstrap"),
		"Event Player trace identifies the confirmed startup execution selector and role"
	)
	_check(
		(player.get("_preview_message_label") as Label).text.contains("Original startup would execute DEF_MAIN.MES here")
		and (player.get("_preview_footer_label") as Label).text.contains("native load/execute/restore confirmed")
		and (player.get("_preview_footer_label") as Label).text.contains("isolated preview stopped")
		and inline_script_result.state_diff.is_empty(),
		"Event Player explains the original inline execution while keeping the preview fail-closed"
	)
	var persistent_trace_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x05, 0x01, 0x02, 0xFF, 0xFF, 0x00, 0x00]),
		0,
		SandboxStateScript.new(1)
	)
	player._show_result(persistent_trace_result, 0)
	_check(
		definition_trace_tree.get_root().get_child(0).get_text(3).contains("stack{destination:d2 0>1; value_0:d0 1>0}"),
		"Event Player trace exposes persistent expression carry without displaying raw payloads"
	)
	var shared_carry_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x0A, 0xFF, 0x01, 0x34, 0xFF, 0x00, 0x1D, 0x02, 0x1C, 0xFF, 0x00]),
		0,
		SandboxStateScript.new(1)
	)
	player._show_result(shared_carry_result, 0)
	_check(
		definition_trace_tree.get_root().get_child(1).get_text(3).contains("routine=28 carry_depth=1 top=1"),
		"Event Player trace exposes the isolated evaluator carry at a shared-routine call boundary"
	)
	var script_dispatch_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x0F, 0x01, 0x54, 0x52, 0x41, 0x49, 0x4E, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00]),
		0,
		player.get("_state")
	)
	player._show_result(script_dispatch_result, 0)
	_check(
		definition_trace_tree.get_root().get_child(0).get_text(3).contains("target=TRAIN.MES")
		and (player.get("_preview_message_label") as Label).text.contains("Nested MES dispatch reached: TRAIN.MES")
		and (player.get("_preview_footer_label") as Label).text.contains("caller restoration not simulated")
		and script_dispatch_result.state_diff.is_empty(),
		"Event Player exposes a bounded command 0x0F target without executing the nested script"
	)
	var script_handoff_result: Dictionary = player.get("_runner").run(
		PackedByteArray([0x0E, 0x01, 0x4D, 0x41, 0x43, 0x48, 0x49, 0x2E, 0x4D, 0x45, 0x53, 0x00, 0x00]),
		0,
		player.get("_state")
	)
	player._show_result(script_handoff_result, 0)
	_check(
		definition_trace_tree.get_root().get_child(0).get_text(3).contains("target=MACHI.MES")
		and (player.get("_preview_message_label") as Label).text.contains("MES handoff marker reached: MACHI.MES")
		and (player.get("_preview_footer_label") as Label).text.contains("host-side consumer not simulated")
		and script_handoff_result.messages.is_empty()
		and script_handoff_result.state_diff.is_empty(),
		"Event Player keeps command 0x0E MES handoffs out of dialogue while preserving the target boundary"
	)
	player.open_content_set(TEST_ROOT)
	var content_summary: Dictionary = player.get("_content_set").get_summary()
	_check(content_summary.archive_count == 5 and content_summary.warnings.size() == 3, "Event Player opens a multi-ARC ELFIMAGE content set")
	_check((player.get("_path_history") as ContentToolPathHistory).get_last_elfimage() == absolute_root.simplify_path(), "Event Player remembers the last successfully opened ELFIMAGE directory")
	_check((player.get_node("ContentSetDialog") as FileDialog).current_dir.simplify_path() == absolute_root.simplify_path(), "Event Player reopens its ELFIMAGE chooser at the remembered directory")
	_check((player.get("start_event_button") as Button).disabled, "Event Player disables one-click event start for an unmatched synthetic MES hash")
	_check((player.get("preview_fragment_button") as Button).disabled, "Event Player disables catalog preview for an unmatched synthetic MES hash")
	_check(
		get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and get_window().content_scale_size == Vector2i(1280, 800)
		and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,
		"Event Player stretches its window content and keeps aspect while windowed"
	)
	_check(player.size == Vector2(1280, 800), "Event Player fills the logical 1280x800 canvas")
	_check(_controls_fit(player), "Event Player controls fit the desktop client area")
	_check(player.has_node("Margin/Layout/Toolbar/Catalog"), "Event Player exposes the Event Catalog browser outside the game frame")
	var catalog_window: Window = player.get_node("CatalogWindow")
	var catalog_tree: Tree = player.get_node("CatalogWindow/Margin/Layout/Split/CatalogTree")
	var catalog_count: Label = player.get_node("CatalogWindow/Margin/Layout/CatalogCountLabel")
	var catalog_character: LineEdit = player.get_node("CatalogWindow/Margin/Layout/Filters/CatalogCharacterFilter")
	var catalog_status: OptionButton = player.get_node("CatalogWindow/Margin/Layout/Filters/CatalogStatusFilter")
	var catalog_details: RichTextLabel = player.get_node("CatalogWindow/Margin/Layout/Split/Right/Settings/SettingsBody/CatalogDetails")
	var catalog_play: Button = player.get_node("CatalogWindow/Margin/Layout/Split/Right/CatalogPlay")
	var catalog_select_source: Button = player.get_node("CatalogWindow/Margin/Layout/Split/Right/CatalogSelectSource")
	_check(catalog_window.min_size == Vector2i(800, 560) and catalog_tree.get_root().get_child_count() == 681, "Event Catalog browser loads all 681 generated rows in a bounded desktop window")
	catalog_character.text = "mahoko"
	player._on_catalog_filter_changed()
	_check(catalog_tree.get_root().get_child_count() == 44 and catalog_count.text.begins_with("44 visible"), "Event Catalog UI filters by character (9 events + her 26 album scenes + her recollection ladder + her 8 conversation scripts)")
	var b03_catalog_item: TreeItem = catalog_tree.get_root().get_first_child()
	while b03_catalog_item != null and str(b03_catalog_item.get_metadata(0)) != "original/eventb03/01m-0000788f":
		b03_catalog_item = b03_catalog_item.get_next()
	_check(b03_catalog_item != null, "Event Catalog character filter includes EVENTB03")
	if b03_catalog_item != null:
		b03_catalog_item.select(0)
	player._on_catalog_event_selected()
	_check(catalog_details.text.contains("minimal_playback") and catalog_details.text.contains("Mahoko at the station (EVENTB03)") and catalog_details.text.contains("MES compatibility") and catalog_details.text.contains("Play readiness"), "Event Catalog selection shows EVENTB03's generated-row playback status and title")
	_check(catalog_play.disabled and catalog_details.text.contains("The analysis route requires its source-bound mes.arc."), "Event Catalog still rejects EVENTB03 Play against a mismatched synthetic source")
	_check(catalog_select_source.disabled, "Event Catalog does not enable source handoff when the selected callee is absent from the open ARC")
	catalog_character.text = ""
	player._on_catalog_filter_changed()
	# The status filters must match the catalog's own counts (since catalog
	# revision 26, 2026-09-23, every generated row is `minimal_playback` and
	# none is `analysis_only`), so the counts are read from the loaded rows.
	var status_counts := {"minimal_playback": 0, "analysis_only": 0}
	for catalog_event in (player.get("_event_catalog") as KakyuEventCatalog).get_events():
		var event_status := str((catalog_event as Dictionary).get("playback_status", ""))
		if status_counts.has(event_status):
			status_counts[event_status] = int(status_counts[event_status]) + 1
	catalog_status.select(1)
	player._on_catalog_filter_changed()
	_check(catalog_tree.get_root().get_child_count() == int(status_counts.minimal_playback) and int(status_counts.minimal_playback) == 681, "Event Catalog UI's minimal-playback status filter matches all 681 generated rows")
	catalog_status.select(2)
	player._on_catalog_filter_changed()
	_check(catalog_tree.get_root().get_child_count() == int(status_counts.analysis_only) and int(status_counts.analysis_only) == 0, "Event Catalog UI's analysis-only status filter matches no row once every row plays")
	catalog_status.select(0)
	player._on_catalog_filter_changed()
	var b01_catalog_item: TreeItem = catalog_tree.get_root().get_first_child()
	while b01_catalog_item != null and str(b01_catalog_item.get_metadata(0)) != "original/eventb01/13c-00000f93":
		b01_catalog_item = b01_catalog_item.get_next()
	_check(b01_catalog_item != null, "Event Catalog unfiltered browser includes EVENTB01")
	if b01_catalog_item != null:
		b01_catalog_item.select(0)
	player._on_catalog_event_selected()
	_check(catalog_play.disabled and catalog_details.text.contains("The analysis route requires its source-bound mes.arc."), "Event Catalog rejects Play when the open synthetic mes.arc is not the cataloged original source")
	var game_preview: ContentToolGamePreview = player.get_node("Margin/Layout/MainSplit/Right/GamePreview")
	_check(game_preview.get_game_viewport().size == Vector2i(640, 400), "Event Player embeds the shared fixed game-frame viewport")
	var compositor_background := Image.create(640, 400, false, Image.FORMAT_RGB8)
	compositor_background.fill(Color(0.1, 0.2, 0.3))
	var compositor_atlas := Image.create(2, 2, false, Image.FORMAT_RGB8)
	compositor_atlas.fill(Color(0, 1, 0))
	compositor_atlas.set_pixel(1, 0, Color(1, 0, 0))
	var background_bound: Dictionary = player._set_preview_surface_background(compositor_background)
	var frame_bound: Dictionary = player._compose_preview_surface_layer(compositor_atlas, Rect2i(0, 0, 2, 2), Vector2i(10, 20))
	var composed_surface: Image = (player.get("_preview_surface_compositor") as Object).call("get_surface_copy", 0)
	_check(
		background_bound.get("ok", false)
		and frame_bound.get("ok", false)
		and str(game_preview.get_compositor_surface_binding().get("schema", "")) == "kakyu_tool_game_preview_compositor_binding/v1"
		and composed_surface != null
		and composed_surface.get_pixel(10, 20).is_equal_approx(compositor_background.get_pixel(10, 20))
		and composed_surface.get_pixel(11, 20).is_equal_approx(Color(1, 0, 0)),
		"Event Player restores green pixels and copies one explicit AN frame through the shared compositor"
	)
	player._restore_preview_surface_background()
	composed_surface = (player.get("_preview_surface_compositor") as Object).call("get_surface_copy", 0)
	_check(
		composed_surface != null
		and composed_surface.get_pixel(11, 20).is_equal_approx(compositor_background.get_pixel(11, 20)),
		"Event Player compositor checkpoint removes the preceding animation frame"
	)
	player._clear_preview_media_state()
	_check(game_preview.size.y >= 260.0, "Event Player reserves a visible desktop panel for the game frame")
	var preview_entry_label: Label = player.get("_preview_entry_label")
	var preview_resource_label: Label = player.get("_preview_background_label")
	_check(not game_preview.get_overlay_root().is_ancestor_of(preview_entry_label), "Event Player keeps entry diagnostics outside the logical game frame")
	_check(not game_preview.get_overlay_root().is_ancestor_of(preview_resource_label), "Event Player keeps media diagnostics outside the logical game frame")
	var original_window_size := get_window().size
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_check(player.size == Vector2(1280, 800) and _controls_fit(player) and game_preview.size.y >= 260.0, "Event Player reflows at 1920x1080")
	_check(game_preview.get_game_viewport().size == Vector2i(640, 400), "1080p output preserves logical CG/AX coordinates")
	get_window().size = Vector2i(2560, 1440)
	await get_tree().process_frame
	_check(player.size == Vector2(1280, 800) and _controls_fit(player) and game_preview.size.y >= 260.0 and game_preview.get_game_viewport().size == Vector2i(640, 400),
		"Event Player reflows at 2560x1440 without changing logical CG/AX coordinates")
	get_window().size = Vector2i(1024, 640)
	await get_tree().process_frame
	_check(player.size == Vector2(1280, 800) and _controls_fit(player), "Event Player remains usable at the shared minimum desktop size")
	_check(game_preview.size.y >= 260.0, "minimum desktop size keeps the game frame visible")
	get_window().size = original_window_size
	await get_tree().process_frame
	_check(player.size == Vector2(original_window_size), "Event Player returns to the desktop test window size")
	var fullscreen_toggle: CheckButton = player.get_node("Margin/Layout/Toolbar/FullscreenToggle")
	_check(fullscreen_toggle != null and not fullscreen_toggle.button_pressed, "Event Player exposes a fullscreen toggle in the toolbar, starting windowed")
	var fullscreen_mode: String = player.toggle_fullscreen()
	_check(
		fullscreen_mode == "fullscreen"
		and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_IGNORE
		and fullscreen_toggle.button_pressed,
		"toggle_fullscreen switches to fullscreen, ignores aspect and checks the toolbar control"
	)
	var windowed_mode: String = player.toggle_fullscreen()
	_check(
		windowed_mode == "windowed"
		and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP
		and not fullscreen_toggle.button_pressed,
		"toggle_fullscreen switches back to windowed, keeps aspect and unchecks the toolbar control"
	)
	var f11_press := InputEventKey.new()
	f11_press.keycode = KEY_F11
	f11_press.pressed = true
	player._input(f11_press)
	_check(fullscreen_toggle.button_pressed and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_IGNORE, "an F11 press through _input toggles fullscreen once")
	var f11_echo := InputEventKey.new()
	f11_echo.keycode = KEY_F11
	f11_echo.pressed = true
	f11_echo.echo = true
	player._input(f11_echo)
	_check(fullscreen_toggle.button_pressed and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_IGNORE, "an F11 echo does not toggle fullscreen")
	var alt_enter := InputEventKey.new()
	alt_enter.keycode = KEY_ENTER
	alt_enter.alt_pressed = true
	alt_enter.pressed = true
	player._input(alt_enter)
	_check(not fullscreen_toggle.button_pressed and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Alt+Enter toggles fullscreen back to windowed")
	var plain_enter := InputEventKey.new()
	plain_enter.keycode = KEY_ENTER
	plain_enter.pressed = true
	player._input(plain_enter)
	_check(not fullscreen_toggle.button_pressed and get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "plain Enter does not toggle fullscreen")
	_check(player.get("_window_display").get_mode() == "windowed", "Event Player scene ends windowed")
	var legacy_date_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/KnownStateFields/LegacyDateEdit")
	var weekday_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/KnownStateFields/WeekdayEdit")
	var hhmm_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/KnownStateFields/HhmmEdit")
	var mahoko_affection_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/KnownStateFields/MahokoAffectionEdit")
	var maki_affection_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/KnownStateFields/MakiAffectionEdit")
	var promise_location_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateButtons/PromiseLocationEdit")
	var apply_promise_location: Button = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateButtons/ApplyPromiseLocation")
	var flag_index_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/FlagStateFields/FlagIndexEdit")
	var flag_value_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/FlagStateFields/FlagValueEdit")
	legacy_date_edit.value = 801
	weekday_edit.value = 6
	hhmm_edit.value = 1230
	mahoko_affection_edit.value = 81
	maki_affection_edit.value = 71
	player.apply_quick_state()
	var sandbox_state = player.get("_state")
	_check(
		sandbox_state.read_value("state_u16", 4) == 6
		and sandbox_state.read_value("state_u16", 7) == 801
		and sandbox_state.read_value("state_u16", 19) == 1230
		and sandbox_state.read_value("banked_u16", 210, 0) == 81
		and sandbox_state.read_value("banked_u16", 212, 0) == 71,
		"Event Player quick fields write the confirmed isolated weekday/date/HHMM/Mahoko/Maki affection slots"
	)
	_check(
		not promise_location_edit.editable and apply_promise_location.disabled,
		"Event Player keeps the PROMIS location control disabled outside a hash-bound original route"
	)
	hhmm_edit.value = 1260
	player.apply_quick_state()
	_check(
		sandbox_state.read_value("state_u16", 19) == 1230
		and (player.get_node("Margin/Layout/StatusLabel") as Label).text.contains("minutes below 60"),
		"Event Player rejects an invalid HHMM quick value without changing sandbox state"
	)
	flag_index_edit.value = 402
	flag_value_edit.value = 1
	player._on_set_quick_flag_pressed()
	_check(
		sandbox_state.read_value("global_u8", 402) == 1
		and (player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateJson") as TextEdit).text.contains("global_u8"),
		"Event Player quick flag editor updates the isolated raw flag and canonical JSON view"
	)
	var invalid_pair := PackedByteArray([0x8F, 0x01])
	var native_diagnostic: Dictionary = player._resolve_message_presentation({
		"source_offset": 10,
		"raw_bytes": invalid_pair,
		"raw_hex": invalid_pair.hex_encode(),
	})
	_check(
		native_diagnostic.source == "native bytes diagnostic"
		and native_diagnostic.text == "Native presentation bytes (not CP932 dialogue)"
		and native_diagnostic.tooltip.contains("Raw bytes (hex): 8f01"),
		"Event Player refuses to promote invalid native pairs through a stale text projection"
	)
	var protagonist_name_edit: LineEdit = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateButtons/ProtagonistNameEdit")
	protagonist_name_edit.text = "Akira"
	var dynamic_presentation: Dictionary = player._resolve_message_presentation({
		"source_offset": 10,
		"dynamic_kind": "protagonist_name",
		"text": protagonist_name_edit.text,
		"resolved": true,
	})
	var preview_fragments: Array[Dictionary] = [
		{"offset": 8, "source": "original CP932", "text": "[", "tooltip": "["},
		dynamic_presentation,
		{"offset": 26, "source": "original CP932", "text": "] hello", "tooltip": "] hello"},
	]
	var composed: Array = player._compose_preview_messages(preview_fragments, {
		"trace": [{"effect": "message_cursor_no_advance"}],
	})
	_check(dynamic_presentation.source == "preview name" and composed.size() == 1 and composed[0].text == "[Akira] hello", "Event Player composes original fragments with the tool-only preview name")
	var nested_raw := "HELLO".to_ascii_buffer()
	player.set("_text_messages", {
		10: {
			"raw_sha256": ContractValues.sha256(nested_raw),
			"text": "Wrong root projection",
		},
	})
	var nested_presentation: Dictionary = player._resolve_message_presentation({
		"source_entry": "L_TALK30.MES",
		"source_offset": 10,
		"raw_bytes": nested_raw,
		"raw_hex": nested_raw.hex_encode(),
	})
	_check(
		nested_presentation.source_entry == "L_TALK30.MES"
		and nested_presentation.source == "original CP932"
		and nested_presentation.text == "HELLO",
		"Event Player keeps selected-entry text projections away from a nested MES source"
	)
	_check(
		player._trace_coordinate_text({"source_entry": "L_TALK30.MES", "source_offset": 0x561}) == "L_TALK30.MES · 0x00000561"
		and player._presentation_source_text(nested_presentation) == "L_TALK30.MES · original CP932",
		"Event Player labels nested trace and dialogue rows with their MES source"
	)
	player.set("_text_messages", {})

	var entry_tree: Tree = player.get_node("Margin/Layout/MainSplit/Sources/EntryTree")
	var entry_item := entry_tree.get_root().get_first_child()
	entry_item.select(0)
	player._on_entry_selected()
	player._on_run_pressed()
	var trace_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/TraceTree")
	var message_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/MessageTree")
	var state_diff_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/StateDiffTree")
	var script_call_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/ScriptCallTree")
	var output: RichTextLabel = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/Output")
	var work_tabs: TabContainer = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs")
	var continue_button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/Continue")
	_check(message_tree.get_root().get_child_count() == 1 and message_tree.get_root().get_first_child().get_text(1) == "TEST.MES · original CP932" and message_tree.get_root().get_first_child().get_text(2) == "HELLO", "Event Player decodes original CP932 and identifies its MES source when no projection is loaded")
	_check((player.get("_preview_message_label") as Label).text == "HELLO", "Event Player presents decoded dialogue inside the game frame")
	_check(game_preview.get_frame_content_rect() == Rect2(Vector2(319, 199), Vector2(2, 2)), "Event Player lazily decodes the traced MMO resource at native pixels")
	_check(
		(player.get("_preview_background_label") as Label).text.contains("BACK.MMO")
		and (player.get("_preview_background_label") as Label).text.contains("native subcommand-9 default-origin load confirmed")
		and (player.get("_preview_background_label") as Label).text.contains("active surface/composition not simulated")
		and (player.get("_preview_background_label") as Label).text.contains("MMO header: standard_mirrored_dimensions · effective original_engine_compatible"),
		"Event Player identifies the traced MMO resource, effective header profile, and unresolved surface composition"
	)
	_check(
		(player.get("_preview_background_label") as Label).text.contains("BACK.AX")
		and (player.get("_preview_background_label") as Label).text.contains("320 cell streams / 2 shared draw records bounded")
		and (player.get("_preview_background_label") as Label).text.contains("native bind cell (0,1) -> stream 0x543")
		and (player.get("_preview_background_label") as Label).text.contains("start opcode 0x05")
		and (player.get("_preview_background_label") as Label).text.contains("surface 8 (2688x864) -> surface 0 (640x400)")
		and (player.get("_preview_background_label") as Label).text.contains("surface-8 content/tick not simulated"),
		"Event Player resolves the exact AX table target selected by the bounded native consumer cell"
	)
	_check((player.get("_preview_background_label") as Label).text.contains("X_MAS.WAV"), "Event Player identifies and validates the traced BGM resource")
	_check(player.get("_preview_bgm_name") == "X_MAS.WAV" and (player.get("_preview_background_label") as Label).text.contains("full payload validated"), "Event Player lazily validates the traced original-format BGM payload in headless mode")
	var initial_audio_state: Dictionary = (player.get("_event_audio_state") as KakyuEventAudioState).snapshot()
	_check(
		initial_audio_state.bgm.entry == "X_MAS.WAV"
		and initial_audio_state.bgm.archive == "bgm.arc"
		and initial_audio_state.bgm.source == "original_arc",
		"Event Player records the BGM as a source-bound common audio-state identity"
	)
	_check((player.get("bgm_toggle_button") as Button).disabled and (player.get("bgm_toggle_button") as Button).text == "BGM validated", "headless Event Player reports validated BGM without claiming interactive playback")
	var original_identities: Dictionary = player.get("_effective_media_identities")
	_check(
		original_identities["mmo.arc/BACK.MMO"].relationship == "exact_original"
		and original_identities["data.arc/BACK.AX"].relationship == "exact_original"
		and original_identities["bgm.arc/X_MAS.WAV"].relationship == "exact_original"
		and (player.get("_preview_background_label") as Label).text.contains("Effective: "),
		"Event Player reports original route evidence separately from exact effective media identities"
	)
	var preset_receipt_state := SandboxStateScript.new(1)
	var preset_receipt_source := {
		"preset_id": "synthetic-original-branch",
		"writes": [
			{"storage": "state_u16", "bank": 0, "index": 19, "value": 1900},
			{"storage": "global_u8", "bank": 0, "index": 642, "value": 0},
		],
	}
	preset_receipt_state.load_values(preset_receipt_source.writes)
	var preset_receipt: Dictionary = player._catalog_preset_application(preset_receipt_state, preset_receipt_source
	)
	preset_receipt_state.write_value("global_u8", 642, 1)
	_check(
		str(preset_receipt.get("schema", ""))
			== ContentCoreVersionScript.EVENT_CATALOG_PRESET_APPLICATION_SCHEMA
		and str(preset_receipt.get("preset_id", "")) == "synthetic-original-branch"
		and (preset_receipt.get("writes", []) as Array) == [
			{"storage": "state_u16", "bank": 0, "index": 19, "value": 1900},
			{"storage": "global_u8", "bank": 0, "index": 642, "value": 0},
		],
		"catalog playback retains a versioned pre-execution preset receipt when runtime state later changes"
	)
	var conflicting_preset_state := SandboxStateScript.new(1)
	var conflicting_preset := {
		"preset_id": "conflicting",
		"writes": [
			{"storage": "global_u8", "bank": 0, "index": 642, "value": 0},
			{"storage": "global_u8", "bank": 0, "index": 642, "value": 1},
		],
	}
	conflicting_preset_state.load_values(conflicting_preset.writes)
	var conflicting_receipt: Dictionary = player._catalog_preset_application(conflicting_preset_state, conflicting_preset
	)
	_check(
		not conflicting_receipt.get("ok", true)
		and str(conflicting_receipt.get("error", "")).contains("conflict"),
		"catalog playback rejects contradictory writes instead of issuing an ambiguous preset receipt"
	)
	var catalog: Object = player.get("_event_catalog")
	var b01_play_request: Dictionary = catalog.build_play_request("original/eventb01/13c-00000f93")
	player.set("_catalog_playback_request", b01_play_request)
	player.set("_catalog_playback_active", true)
	player.set("_selected_entry", "EVENTB01.MES")
	var b01_callee_terminal: Dictionary = player._catalog_terminal_match_for_result({
		"status": "script_return",
		"offset": 0x6A0,
		"trace": [],
	})
	_check(
		b01_callee_terminal.get("ok", false)
		and str(b01_callee_terminal.get("phase", "")) == "callee_return"
		and not bool(b01_callee_terminal.get("route_ended", true)),
		"catalog playback classifies an exact callee return as continuation rather than event completion"
	)
	player.set("_selected_entry", "13C.MES")
	var b01_final_terminal: Dictionary = player._catalog_terminal_match_for_result({
		"status": "script_handoff_boundary",
		"offset": 0x1022,
		"trace": [{
			"step": 0,
			"source_offset": 0x1022,
			"command_id": 0x0F,
			"op": "script_dispatch",
			"target_entry": "MACHI.MES",
		}],
	})
	player.set("_preview_event_session", "")
	player._show_result({
		"ok": true,
		"status": "script_handoff_boundary",
		"offset": 0x1022,
		"resume_offset": -1,
		"trace": [{
			"step": 0,
			"source_offset": 0x1022,
			"command_id": 0x0F,
			"op": "script_dispatch",
			"target_entry": "MACHI.MES",
		}],
		"messages": [],
		"definitions": [],
		"calls": [],
		"state_diff": [],
		"argument_slots": {},
		"persistent_expression_stack": [],
	}, 0)
	_check(
		b01_final_terminal.get("ok", false)
		and bool(b01_final_terminal.get("route_ended", false))
		and str(b01_final_terminal.get("display", "")) == "event_complete"
		and bool(player.get("_preview_event_complete"))
		and bool(player.get("_preview_completion_shown"))
		and (player.get("_preview_message_label") as Label).text.contains("Event complete")
		and (player.get("_preview_footer_label") as Label).text.contains("MACHI.MES")
		and (player.get("_preview_footer_label") as Label).text.contains("outer host not executed"),
		"catalog playback renders a generic completion only at the exact caller-owned final handoff"
	)
	var changed_terminal_request := b01_play_request.duplicate(true)
	changed_terminal_request.terminal_contract.stages[1].offset = 0
	player.set("_catalog_playback_request", changed_terminal_request)
	var changed_terminal_match: Dictionary = player._catalog_terminal_match_for_result({
		"status": "script_handoff_boundary",
		"offset": 0x1022,
		"trace": [{"target_entry": "MACHI.MES"}],
	})
	var changed_terminal_readiness: Dictionary = player._catalog_play_readiness(changed_terminal_request)
	_check(
		not changed_terminal_match.get("ok", true)
		and str(changed_terminal_match.get("error", "")).contains("changed after it was issued")
		and not changed_terminal_readiness.get("ok", true)
		and str(changed_terminal_readiness.get("error", "")).contains("differs from the current catalog"),
		"catalog playback rejects a terminal contract changed after the play request was issued"
	)
	player.set("_catalog_playback_active", false)
	player.set("_catalog_playback_request", {})
	player.set("_catalog_terminal_match", {})
	player.set("_selected_entry", "TEST.MES")
	player._run_confirmed_event_execution({"event_start_kind": "dialogue"}, 0, {})
	_check(
		str(player.get("_preview_result_status")) == "dialogue_boundary"
		and (player.get("_preview_message_label") as Label).text == "HELLO",
		"ordinary confirmed starts execute their MES intro instead of stopping after session setup"
	)
	_check(not continue_button.disabled and int(player.get("_continuation_offset")) > 0, "supported dialogue boundary enables an explicit continuation")
	_check((player.get("_preview_footer_label") as Label).text.contains("Continue"), "game frame advertises keyboard and pointer continuation at the final message")
	player.set("_catalog_playback_active", true)
	player.step_preview_message(1)
	_check(not continue_button.disabled and (player.get("_preview_message_label") as Label).text == "NEXT", "game-frame input resumes through a message record ID to the next dialogue boundary")
	_check(player.get("_preview_mmo_name") == "BACK.MMO" and game_preview.get_frame_content_rect() == Rect2(Vector2(319, 199), Vector2(2, 2)), "continuation retains the last confirmed MMO in the tool frame")
	_check(player.get("_preview_ax_name") == "BACK.AX", "continuation retains the last structurally validated AX metadata")
	_check((player.get("_preview_background_label") as Label).text.contains("MMO unchanged") and (player.get("_preview_background_label") as Label).text.contains("AX unchanged") and (player.get("_preview_background_label") as Label).text.contains("BGM unchanged"), "continuation labels retained MMO, AX, and BGM session state without inferring new requests")
	_check(player.get("_preview_voice_name") == "XQZ01.OGG" and player.get("_preview_voice_archive") == "voice.arc", "Event Player resolves the bounded MES voice marker through the original voice archive")
	var voice_audio_state: Dictionary = (player.get("_event_audio_state") as KakyuEventAudioState).snapshot()
	_check(
		voice_audio_state.active_voices.size() == 1
		and voice_audio_state.active_voices[0].entry == "XQZ01.OGG"
		and voice_audio_state.active_voices[0].source == "original_arc",
		"Event Player records the voice marker in the shared effective-identity state"
	)
	_check(
		(player.get("_preview_background_label") as Label).text.contains("full payload validated")
		and (player.get("_preview_background_label") as Label).text.contains("native DirectSound Play dispatch confirmed")
		and (player.get("_preview_background_label") as Label).text.contains("device output not observed"),
		"headless voice preview separates the confirmed native Play dispatch from observed device output"
	)
	player.step_preview_message(1)
	_check(continue_button.disabled and int(player.get("_continuation_offset")) == -1 and output.text.contains("script_return"), "confirmed script return after the next dialogue completes the synthetic preview without another resume")
	_check(bool(player.get("_catalog_playback_active")), "ordinary catalog playback stays active across user-visible dialogue continuations")
	player.set("_catalog_playback_active", false)
	_check((player.get("_preview_message_label") as Label).text.contains("caller is not simulated") and (player.get("_preview_footer_label") as Label).text.contains("Preview complete"), "game frame distinguishes a completed callee from an unsupported stop")
	player.set("_catalog_playback_active", true)
	player.set("_catalog_terminal_rejected_completion", true)
	player.set("_catalog_terminal_match", {"ok": false, "error": "changed terminal"})
	player.set("_continuation_offset", 0x123)
	player.set("_continuation_context", {"kind": "dialogue"})
	player.set("_preview_messages", [])
	player.set("_choice_projection", {})
	player.set("_view_mode", "playback")
	var rejected_terminal_drive: Dictionary = player._drive_catalog_playback_to_user_boundary()
	_check(
		not rejected_terminal_drive.get("ok", true)
		and int(player.get("_continuation_offset")) == 0x123
		and not bool(player.get("_catalog_playback_active")),
		"catalog playback stops before executing a continuation after terminal-contract rejection"
	)
	player.set("_catalog_terminal_rejected_completion", false)
	player.set("_catalog_terminal_match", {})
	player.set("_catalog_playback_active", true)
	player.set("_preview_messages", [])
	player.set("_choice_projection", {})
	player.set("_continuation_offset", -1)
	player.set("_preview_event_complete", false)
	player.set("_preview_result_status", "unsupported_opcode")
	player.set("_view_mode", "playback")
	player.set("_catalog_playback_request", {"event_id": "synthetic/fail-closed"})
	var unresolved_catalog_drive: Dictionary = player._drive_catalog_playback_to_user_boundary()
	_check(
		not unresolved_catalog_drive.get("ok", true)
		and not bool(player.get("_catalog_playback_active"))
		and (player.get("_catalog_playback_request") as Dictionary).is_empty()
		and str(unresolved_catalog_drive.get("error", "")).contains("unresolved unsupported_opcode"),
		"catalog playback fails closed instead of presenting an unsupported terminal as complete (%s active=%s)" % [
			str(unresolved_catalog_drive),
			str(player.get("_catalog_playback_active")),
		]
	)
	player._configure_text_cache(cache_root)
	player.reset_state()
	_check(protagonist_name_edit.text.is_empty(), "sandbox reset clears the tool-only preview name")
	player._on_run_pressed()
	_check(trace_tree.get_root().get_child_count() >= 2, "Event Player presents opcode trace records in a dedicated result tab")
	_check(
		script_call_tree.columns == 4
		and player.get("result_tabs").get_tab_title(3) == "Script Calls",
		"Event Player exposes a dedicated call table for result provenance (columns=%d rows=%d tab=%s)" % [
			script_call_tree.columns,
			script_call_tree.get_root().get_child_count(),
			player.get("result_tabs").get_tab_title(3),
		]
	)
	_check(message_tree.get_root().get_child_count() == 1 and message_tree.get_root().get_first_child().get_text(2) == "Localized hello", "Event Player presents hash-bound UTF-8 messages separately")
	_check((player.get("_preview_message_label") as Label).text == "Localized hello", "game frame follows the hash-bound UTF-8 presentation")
	# Core 0.377.0 (TD-56): the fixture's command-0x09 argument assignments land in global_i32,
	# the storage token 0xF6 reads, so the sandbox diff lists that cell beside the global_u8 write.
	_check(
		state_diff_tree.get_root().get_child_count() == 2
		and state_diff_tree.get_root().get_first_child().get_text(0) == "global_i32"
		and state_diff_tree.get_root().get_first_child().get_text(2) == "1"
		and state_diff_tree.get_root().get_first_child().get_text(3) == "0 -> 26"
		and state_diff_tree.get_root().get_first_child().get_next().get_text(0) == "global_u8",
		"Event Player presents isolated state changes separately"
	)
	_check(output.text.contains("dialogue_boundary") and output.text.contains("Continue"), "Event Player summary exposes the supported continuation coordinate")
	_check(work_tabs.current_tab == 1, "Event Player switches from sandbox input to results after a run")

	var overlay_reader := ArcReaderScript.new()
	_check(overlay_reader.open(archive_path), "Event Player test source opens for an overlay-package probe")
	var overlay_package := OverlayPackageScript.new()
	var raw_sha := OverlayPackageScript.sha256_bytes("HELLO".to_ascii_buffer())
	var staged := overlay_package.stage_mes_text_projection(
		overlay_root,
		overlay_reader,
		"mes.arc",
		"TEST.MES",
		[{"source_offset": 8, "raw_sha256": raw_sha, "text": "Overlay hello"}]
	)
	_check(staged.ok, "Event Player test stages a workspace MES text overlay through the shared core")
	overlay_reader.close()
	player._on_run_pressed()
	_check(
		message_tree.get_root().get_first_child().get_text(1) == "TEST.MES · UTF-8 cache"
		and message_tree.get_root().get_first_child().get_text(2) == "Localized hello"
		and (player.get("_preview_message_label") as Label).text == "Localized hello",
		"Event Player never activates a workspace overlay text projection; cache text is unchanged"
	)
	_check(
		FileAccess.get_sha256(archive_path) == source_sha
		and FileAccess.get_sha256(image_archive_path) == image_source_sha
		and FileAccess.get_sha256(data_archive_path) == data_source_sha
		and FileAccess.get_sha256(bgm_archive_path) == bgm_source_sha
		and FileAccess.get_sha256(voice_archive_path) == voice_source_sha,
		"Event Player leaves every content-set ARC unchanged"
	)

	player.queue_free()
	await get_tree().process_frame
	_cleanup()
	get_tree().quit(1 if _failed else 0)


func _controls_fit(player: KakyuEventPlayer) -> bool:
	var margin: Control = player.get_node("Margin")
	var layout: Control = player.get_node("Margin/Layout")
	var fits := Rect2(Vector2.ZERO, player.size).encloses(margin.get_rect()) and margin.get_rect().size.y >= layout.get_combined_minimum_size().y
	if not fits:
		print("Event Player layout diagnostics: viewport=", player.size, " margin=", margin.get_rect(), " minimum=", layout.get_combined_minimum_size())
	return fits


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _write_bytes(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(value)
	file.close()


func _synthetic_mes() -> PackedByteArray:
	var code := PackedByteArray([
		0x03, 0x34, 0x12,
		0xF1, 20, 0, 0xFF, 0,
		0x01,
	])
	code.append_array("HELLO".to_ascii_buffer())
	code.append(0)
	code.append_array(PackedByteArray([
		0x0D, 0x09, 0xFF, 0x01, 0x42, 0x41, 0x43, 0x4B, 0x2E, 0x4D, 0x4D, 0x4F, 0x00, 0x00,
		0x0D, 0x08, 0xFF, 0x02, 0x00, 0xFF, 0x01, 0x42, 0x41, 0x43, 0x4B, 0x2E, 0x41, 0x58, 0x00, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00,
		0x09, 0x01, 0x00, 0xF1, 0x1A, 0x00, 0xFF, 0x00,
		0x0D, 0x03, 0xFF, 0x02, 0x00, 0xFF, 0x02, 0x00, 0xFF, 0x02, 0x01, 0xFF, 0x02, 0x02, 0xF9, 0x00, 0xFF, 0x00,
		0x1D, 0x02, 0xF1, 0x17, 0x00, 0xFF, 0x00,
		0x1F, 0x1B, 0x00, 0x01, 0x00,
		0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
		0x09, 0x01, 0x00, 0xF1, 0x4D, 0x00, 0xFF, 0x00,
		0x1D, 0x02, 0x00, 0xFF, 0x00,
		0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x80, 0x00, 0xE9, 0xFF, 0x00,
		0x0D, 0x07, 0xFF, 0x02, 0x02, 0xFF, 0x01, 0x78, 0x71, 0x7A, 0x30, 0x31, 0x2E, 0x6F, 0x67, 0x67, 0x00, 0x02, 0x00, 0xFF, 0x00,
		0x07, 0x02, 0xFF, 0x00, 0x02, 0xA0, 0x00, 0xF1, 0x7F, 0xFF, 0xE8, 0xFF, 0x00,
		0x01, 0x4E, 0x45, 0x58, 0x54, 0x00,
		0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00,
	]))
	code.append(0x00)
	var mes := PackedByteArray()
	SyntheticArc.append_u32(mes, 1)
	SyntheticArc.append_u32(mes, 0)
	mes.append_array(code)
	return mes


func _synthetic_wav(sample_rate := 8000) -> PackedByteArray:
	var sample_data := PackedByteArray([128, 128, 128, 128, 128, 128, 128, 128])
	var wav := PackedByteArray()
	wav.append_array("RIFF".to_ascii_buffer())
	SyntheticArc.append_u32(wav, 36 + sample_data.size())
	wav.append_array("WAVEfmt ".to_ascii_buffer())
	SyntheticArc.append_u32(wav, 16)
	SyntheticArc.append_u16(wav, 1)
	SyntheticArc.append_u16(wav, 1)
	SyntheticArc.append_u32(wav, sample_rate)
	SyntheticArc.append_u32(wav, sample_rate)
	SyntheticArc.append_u16(wav, 1)
	SyntheticArc.append_u16(wav, 8)
	wav.append_array("data".to_ascii_buffer())
	SyntheticArc.append_u32(wav, sample_data.size())
	wav.append_array(sample_data)
	return wav


func _synthetic_ax() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(0x538)
	data.fill(0)
	_write_ax_record(data, 0x500, 0, 0, 0, 32, 24, 10, 20)
	_write_ax_record(data, 0x51C, 1, 32, 0, 40, 30, 100, 120)
	for index in range(320):
		data.encode_u32(index * 4, data.size())
		if index == 0:
			data.append_array(PackedByteArray([1, 3, 0, 0, 0, 9, 1, 0, 0, 0, 0xFF]))
		elif index == 1:
			data.append_array(PackedByteArray([5, 2, 0, 0, 0, 9, 0, 0, 0, 0, 6, 0xFF]))
		else:
			data.append(0xFF)
	return data


func _write_ax_record(data: PackedByteArray, offset: int, dispatch_type: int, source_x: int, source_y: int, width: int, height: int, destination_x: int, destination_y: int) -> void:
	var values := [dispatch_type, source_x, source_y, width, height, destination_x, destination_y]
	for index in range(values.size()):
		data.encode_u32(offset + index * 4, int(values[index]))


func _synthetic_ogg(sample_rate := 44100) -> PackedByteArray:
	var ogg := PackedByteArray()
	ogg.resize(58)
	ogg.fill(0)
	ogg.encode_u32(0, 0x5367674F)
	ogg[5] = 0x02
	ogg[26] = 1
	ogg[27] = 30
	ogg[28] = 1
	ogg.encode_u32(29, 0x62726F76)
	ogg.encode_u16(33, 0x7369)
	ogg[39] = 1
	ogg.encode_u32(40, sample_rate)
	ogg[56] = 0xB8
	ogg[57] = 1
	return ogg


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
			"source_offset": 8,
			"text": "Localized hello",
			"raw_sha256": _sha256("HELLO".to_ascii_buffer()),
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


func _routine40_bridge_code() -> PackedByteArray:
	var code := PackedByteArray()
	_append_routine40_definition(code, 0, "A", 1)
	_append_routine40_definition(code, 1, "B", 2)
	_append_routine40_definition(code, 2, "C", 3)
	code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	code.append_array(PackedByteArray([0x1F, 0x04, 0x00, 0x00, 0x00]))
	var first_branch := _append_routine40_result_branch(code, 1)
	var first_option := code.size()
	code.append(0x00)
	var second_branch := code.size()
	code.encode_u32(first_branch + 6, second_branch)
	_append_routine40_result_branch(code, 2)
	var second_option := code.size()
	code.append(0x00)
	var third_option := code.size()
	code.append(0x00)
	code.encode_u32(second_branch + 6, third_option)
	assert(first_option < second_option and second_option < third_option)
	return code


func _routine40_single_bridge_code() -> PackedByteArray:
	var code := PackedByteArray()
	_append_routine40_definition(code, 2, "ONLY", 7)
	code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var branch := _append_routine40_result_branch(code, 1)
	code.append(0x00)
	var fallback := code.size()
	code.append(0x00)
	code.encode_u32(branch + 6, fallback)
	return code


func _routine40_gated_bridge_code() -> PackedByteArray:
	var code := PackedByteArray()
	_append_routine40_definition(code, 0, "A", 1)
	_append_routine40_definition(code, 1, "B", 2)
	_append_routine40_definition(code, 2, "C", 3)
	code.append_array(PackedByteArray([0x1D, 0x02, 0x28, 0xFF, 0x00]))
	var branches: Array[int] = []
	for result_value in range(1, 4):
		for gate_value in [0, 1]:
			branches.append(_append_routine40_gated_result_branch(code, result_value, 7, gate_value))
			code.append(0x00)
	var fallback := code.size()
	code.append(0x00)
	for index in range(branches.size()):
		code.encode_u32(
			branches[index] + 12,
			branches[index + 1] if index + 1 < branches.size() else fallback
		)
	return code


func _append_routine40_definition(code: PackedByteArray, definition_id: int, text: String, marker: int) -> void:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x10, 0x02, definition_id, 0xFF, 0x00]))
	code.resize(code.size() + 4)
	code.append(0x01)
	code.append_array(text.to_ascii_buffer())
	code.append_array(PackedByteArray([0x00, 0x00]))
	var target := code.size()
	code.encode_u32(source_offset + 5, target)
	code.append(0x1F)
	code.resize(code.size() + 4)
	code.encode_u32(code.size() - 4, marker)


func _append_routine40_result_branch(code: PackedByteArray, result_value: int) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([0x0B, 0x80, 21, result_value, 0xEF, 0xFF]))
	code.resize(code.size() + 4)
	return source_offset


func _append_grouped_routine40_consumer(code: PackedByteArray) -> void:
	var first_one := _append_routine40_compound_result_branch(code, 1, 1)
	code.append(0x00)
	var first_two := _append_routine40_result_branch(code, 2)
	code.encode_u32(first_one + 11, first_two)
	code.append(0x00)
	var fallback := code.size()
	code.encode_u32(first_two + 6, fallback)
	code.append(0x0C)
	var destination := fallback + 5
	code.resize(destination)
	code.encode_u32(fallback + 1, destination)
	code.append(0x00)


func _append_routine40_compound_result_branch(
	code: PackedByteArray, first_result: int, second_result: int
) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([
		0x0B,
		0x80, 21, first_result, 0xEF,
		0x80, 13, second_result, 0xEF,
		0xE6, 0xFF,
	]))
	code.resize(code.size() + 4)
	return source_offset


func _append_routine40_gated_result_branch(
	code: PackedByteArray, result_value: int, gate_index: int, gate_value: int
) -> int:
	var source_offset := code.size()
	code.append_array(PackedByteArray([
		0x0B, 0x80, 21, result_value, 0xEF,
		0xF3, gate_index & 0xFF, (gate_index >> 8) & 0xFF, gate_value,
		0xEF, 0xE6, 0xFF,
	]))
	code.resize(code.size() + 4)
	return source_offset


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()


func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()


func _test_catalog_preset_selector_ui(player: KakyuEventPlayer) -> void:
	var original_catalog: Object = player.get("_event_catalog")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/event_catalog/original_events_v1.json"))
	var event_id := "original/eventb03/01m-0000788f"
	var explicit_id := "synthetic-explicit-original"
	var analysis_id := "synthetic-analysis-only"
	var long_label := "Explicit synthetic original preset " + "long label ".repeat(20)
	for event in document.events:
		if event.event_id == event_id:
			event.presets.append({"preset_id": explicit_id, "label": long_label, "kind": "original_branch", "writes": [{"storage": "state_u16", "bank": 0, "index": 12, "value": 100, "evidence_level": "confirmed"}], "expected_branch_ids": [], "notes": "Synthetic explicit-preset selection metadata."})
			event.presets.append({"preset_id": analysis_id, "label": "Synthetic analysis-only preset", "kind": "tool_seeded_analysis", "writes": [], "expected_branch_ids": [], "notes": "Not ordinary playback."})
	var catalog := EventCatalogScript.new()
	_check(catalog.validate(document).get("ok", false), "preset selector fixture has multiple original and analysis presets")
	var retained := {}
	for field in ["_state", "_selected_entry", "_document", "_preview_event_session", "_preview_mmo_name", "_catalog_playback_active", "_catalog_playback_request"]:
		retained[field] = player.get(field)
	var sentinel := SandboxStateScript.new(1)
	sentinel.write_value("state_u16", 12, 77)
	player.set("_state", sentinel)
	player.set("_selected_entry", "ACTIVE_SYNTHETIC.MES")
	player.set("_document", {"ok": true, "source": {"resolved_source": "synthetic"}})
	player.set("_preview_event_session", "active_synthetic")
	player.set("_preview_mmo_name", "ACTIVE_SYNTHETIC.MMO")
	player.set("_catalog_playback_active", true)
	player.set("_catalog_playback_request", {"event_id": "active_synthetic", "preset": {"preset_id": "active-preset"}})
	player.set("_event_catalog", catalog)
	var selector: OptionButton = player.get("catalog_preset_select")
	var details: RichTextLabel = player.get("catalog_details")
	var play: Button = player.get("catalog_play_button")
	var before := _catalog_root_binding_observation(player)
	player._rebuild_event_catalog_browser()
	_check(selector.disabled and selector.item_count == 0 and play.disabled and not player._catalog_selected_play_request().get("ok", true), "preset selector is empty and Play is disabled without an event")
	_select_catalog_event_for_preset_test(player, event_id)
	var recommended_id := str(catalog.build_play_request(event_id).preset.preset_id)
	_check(not selector.disabled and selector.item_count == catalog.get_event(event_id).presets.size() and str(selector.get_item_metadata(selector.selected)) == recommended_id and str(player.get("_catalog_preset_event_id")) == event_id, "event selection shows every preset and selects its recommended original ID")
	var explicit_index := _catalog_preset_index_for_test(selector, explicit_id)
	selector.select(explicit_index)
	selector.emit_signal("item_selected", explicit_index)
	var selected: Dictionary = player._catalog_selected_play_request()
	_check(selected.get("ok", false) and selected.preset.preset_id == explicit_id and selected.preset.writes[0].value == 100 and details.text.contains("Selected preset: " + long_label), "preset selection builds readiness from its explicit ID and displays selected metadata")
	_check(_catalog_root_binding_observation(player) == before, "choosing another preset leaves the active source, state, preview and playback request unchanged")
	player._on_catalog_event_selected()
	_check(str(selector.get_item_metadata(selector.selected)) == explicit_id, "refreshing the same event retains its selected preset ID")
	var analysis_index := _catalog_preset_index_for_test(selector, analysis_id)
	selector.select(analysis_index)
	selector.emit_signal("item_selected", analysis_index)
	_check(play.disabled and not player._catalog_selected_play_request().get("ok", true) and play.tooltip_text.contains("analysis"), "analysis-only preset remains inspectable but cannot enable ordinary Play")
	player._on_catalog_play_pressed()
	_check(details.text.contains("Play rejected: This preset is for analysis") and _catalog_root_binding_observation(player) == before, "actual Play uses the selected analysis preset and rejects it without falling back or mutating live playback")
	_select_catalog_event_for_preset_test(player, "original/eventb01/13c-00000f93")
	_check(str(selector.get_item_metadata(selector.selected)) == "13c-b01-baseline", "changing events resets selection to the new event's recommended preset")
	_select_catalog_event_for_preset_test(player, event_id)
	_check(str(selector.get_item_metadata(selector.selected)) == recommended_id, "returning to an event resets to its recommendation rather than a prior event selection")
	selector.select(-1)
	selector.emit_signal("item_selected", -1)
	player._on_catalog_play_pressed()
	_check(play.disabled and selector.selected == -1 and not player._catalog_selected_play_request().get("ok", true) and _catalog_root_binding_observation(player) == before, "missing preset selection fails closed without a default fallback")
	selector.select(_catalog_preset_index_for_test(selector, explicit_id))
	selector.emit_signal("item_selected", selector.selected)
	var removed := document.duplicate(true)
	for event in removed.events:
		if event.event_id == event_id:
			event.presets = event.presets.filter(func(preset: Dictionary) -> bool: return str(preset.preset_id) != explicit_id)
	_check(catalog.validate(removed).get("ok", false), "preset removal fixture keeps the catalog structurally valid")
	player._on_catalog_play_pressed()
	_check(play.disabled and not player._catalog_selected_play_request().get("ok", true) and details.text.contains("no longer in the current catalog") and _catalog_root_binding_observation(player) == before, "stale dropdown metadata cannot play a removed preset")
	player._on_catalog_event_selected()
	_check(selector.selected == -1 and play.disabled and selector.tooltip_text.contains("previous preset is no longer available"), "same-event refresh clears a removed preset and requires explicit replacement")
	player._on_catalog_event_selected()
	_check(selector.selected == -1 and play.disabled, "repeated refresh does not silently replace a missing preset")
	selector.select(_catalog_preset_index_for_test(selector, recommended_id))
	selector.emit_signal("item_selected", selector.selected)
	_check(player._catalog_selected_play_request().get("ok", false) and not selector.tooltip_text.contains("previous preset is no longer available"), "explicitly selecting an available preset recovers from removal")
	player.set("_catalog_preset_event_id", "original/eventb01/13c-00000f93")
	player._on_catalog_play_pressed()
	_check(play.disabled and not player._catalog_selected_play_request().get("ok", true) and _catalog_root_binding_observation(player) == before, "dropdown selection cannot be reused under another event identity")
	var text_filter: LineEdit = player.get("catalog_text_filter")
	text_filter.text = "no-such-catalog-event"
	player._on_catalog_filter_changed()
	_check(selector.disabled and selector.item_count == 0 and str(player.get("_catalog_preset_event_id")).is_empty() and play.disabled, "filtering clears the prior event-bound preset and disables Play")
	player._on_catalog_play_pressed()
	_check(_catalog_root_binding_observation(player) == before, "Play without a filtered event preserves active playback")
	text_filter.text = ""
	player._on_catalog_filter_changed()
	var empty := document.duplicate(true)
	for event in empty.events:
		if event.event_id == event_id:
			event.presets = []
	_check(catalog.validate(empty).get("ok", false), "empty preset fixture is structurally valid")
	_select_catalog_event_for_preset_test(player, event_id)
	_check(selector.disabled and selector.item_count == 0 and play.disabled, "events without presets expose an empty disabled selector")
	_check(catalog.validate(document).get("ok", false), "preset selector fixture can restore its original choices")
	player._rebuild_event_catalog_browser()
	_select_catalog_event_for_preset_test(player, event_id)
	selector.select(_catalog_preset_index_for_test(selector, explicit_id))
	selector.emit_signal("item_selected", selector.selected)
	var original_window_size := get_window().size
	var catalog_window: Window = player.get("catalog_window")
	var original_catalog_size := catalog_window.size
	var original_catalog_visible := catalog_window.visible
	catalog_window.show()
	# A row whose guard has many cells (or many visit presets) must not push
	# the Play button out of the window: the run settings scroll, the buttons
	# stay pinned below them (2026-09-24, owner report).
	var run_settings_form: VBoxContainer = player.get("catalog_state_form")
	var run_settings_fillers: Array[Control] = []
	for filler_index in range(60):
		var filler := Label.new()
		filler.text = "starting-state field %d" % filler_index
		run_settings_form.add_child(filler)
		run_settings_fillers.append(filler)
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1024, 640)]:
		get_window().size = size
		catalog_window.size = Vector2i(1050, 700) if size.x > 1024 else Vector2i(800, 560)
		await get_tree().process_frame
		await get_tree().process_frame
		var catalog_client := Rect2(Vector2.ZERO, Vector2(catalog_window.size))
		_check(play.is_visible_in_tree() and catalog_client.encloses(play.get_global_rect()), "the catalog Play button stays inside the window beside a 60-field starting-state form at %dx%d" % [size.x, size.y])
		var parent: Control = selector.get_parent()
		_check(selector.size.x > 0 and selector.position.x >= 0 and selector.position.x + selector.size.x <= parent.size.x + 1 and not selector.fit_to_longest_item and player.get("game_preview").get_game_viewport().size == Vector2i(640, 400), "long preset labels fit the catalog selector at %dx%d without changing logical gameplay coordinates" % [size.x, size.y])
	for filler in run_settings_fillers:
		run_settings_form.remove_child(filler)
		filler.free()
	catalog_window.visible = original_catalog_visible
	catalog_window.size = original_catalog_size
	get_window().size = original_window_size
	await get_tree().process_frame
	_check(_catalog_root_binding_observation(player) == before, "preset refresh, selection and layout checks preserve the live session")
	for field in retained:
		player.set(field, retained[field])
	player.set("_event_catalog", original_catalog)
	player._rebuild_event_catalog_browser()
	_test_catalog_result_selector_ui(player)
	_test_catalog_guard_form_ui(player)


func _test_catalog_guard_form_ui(player: KakyuEventPlayer) -> void:
	# EP-10 unit 5b/c: every seeded row carries `analysis_group` now, so the
	# "Use this state" toggle is shown for every row. With the tracked
	# catalog and no archive, selecting a promoted row builds the guard
	# form from its v4 document's fields and bounds, shows the toggle, and
	# disables it with the archive-not-open text.
	var form: VBoxContainer = player.get("catalog_state_form")
	var toggle: CheckButton = player.get("catalog_use_form_state")
	var k_date3_id := "original/eventk15/k_date3-000043da"
	_select_catalog_event_for_preset_test(player, k_date3_id)
	_check(toggle.visible, "k_date3's (promoted) guard form shows the toggle")
	var fields: Array = player.get("_catalog_guard_fields")
	_check(fields.size() == 3, "k_date3's guard form builds its distinct cell fields")
	var found_date := false
	var found_flag := false
	for field_value in fields:
		var field: Dictionary = field_value
		if str(field.storage) == "state_u16" and int(field.index) == 7:
			found_date = true
			_check(int(field.min) == 1116 and int(field.max) == 1510, "k_date3's date field carries its measured bounds")
		if str(field.storage) == "global_u8" and int(field.index) == 2341:
			found_flag = true
			_check(int(field.fixed) == 0, "k_date3's global_u8[2341] field carries its measured fixed value")
	_check(found_date and found_flag, "k_date3's guard form names the date and flag cells")
	_check(form.get_child_count() > 0, "k_date3's guard form built at least one row")
	_check(toggle.disabled and not toggle.button_pressed, "k_date3's guard form toggle is disabled with no archive open")
	var guard_line: Label = form.get_node_or_null("GuardLine")
	_check(guard_line != null and guard_line.text == "Guard: archive not open", "k_date3's guard line reports the archive is not open")


func _test_catalog_result_selector_ui(player: KakyuEventPlayer) -> void:
	# EP-10 unit 2: the catalog "Result" selector exposes a promoted
	# analysis-group choice row's options and hides for a plain promoted row.
	var result_selector: OptionButton = player.get("catalog_result_select")
	var play: Button = player.get("catalog_play_button")
	var choice_row_id := "original/eventa01/27c3b-00000697"
	var choice_row := (player.get("_event_catalog") as KakyuEventCatalog).get_event(choice_row_id)
	_select_catalog_event_for_preset_test(player, choice_row_id)
	_check(
		result_selector.visible and not result_selector.disabled and result_selector.item_count == choice_row.choices[0].options.size(),
		"a promoted choice row shows the result selector with its options",
	)
	# EP-10 unit 4 / Round 2 code review: the promoted row's button text
	# follows the view mode - "Play" in Playback, "Analyze route" in
	# Analysis - and the button (`_on_catalog_play_pressed`) picks between
	# the public `play_catalog_request` and `analyze_catalog_request` by
	# that same mode; with the tracked catalog and no archive open, both
	# are refused with the same source-bound-archive message.
	player.set("_view_mode", player.VIEW_MODE_PLAYBACK)
	player._refresh_catalog_event_details()
	_check(play.text == "Play", "a promoted analysis-group row shows Play in Playback view mode")
	var choice_play_request: Dictionary = player._catalog_selected_play_request()
	var choice_played: Dictionary = player.play_catalog_request(choice_play_request)
	_check(
		not choice_played.get("ok", true) and str(choice_played.get("error", "")) == "The analysis route requires its source-bound mes.arc.",
		"Play on a promoted row is refused with the archive message, as Analyze is",
	)
	var choice_analyzed: Dictionary = player.analyze_catalog_request(choice_play_request)
	_check(
		not choice_analyzed.get("ok", true) and str(choice_analyzed.get("error", "")) == "The analysis route requires its source-bound mes.arc.",
		"analyze_catalog_request on a promoted row is refused with the same archive message",
	)
	player.set("_view_mode", player.VIEW_MODE_ANALYSIS)
	player._refresh_catalog_event_details()
	_check(play.text == "Analyze route", "the same promoted row shows Analyze route in Analysis view mode")
	player.set("_view_mode", player.VIEW_MODE_PLAYBACK)
	player._refresh_catalog_event_details()
	# Round 9 code review, item 1: changing the Result re-picks the measured
	# preset for the new option, unless the currently selected preset's
	# named variant already selects it. Option-1's variant (result1-baseline)
	# does not select option-2's value, so the preset must change.
	var preset_selector: OptionButton = player.get("catalog_preset_select")
	var option1_index := _catalog_result_index_for_test(result_selector, "option-1")
	result_selector.select(option1_index)
	result_selector.emit_signal("item_selected", option1_index)
	var option1_preset_id := str(preset_selector.get_item_metadata(preset_selector.selected))
	var option2_index := _catalog_result_index_for_test(result_selector, "option-2")
	result_selector.select(option2_index)
	result_selector.emit_signal("item_selected", option2_index)
	var option2_request: Dictionary = player._catalog_selected_play_request()
	var option2_preset_id := str(preset_selector.get_item_metadata(preset_selector.selected))
	_check(
		option2_request.get("ok", false) and str(option2_request.selection.option_id) == "option-2" and option2_preset_id != option1_preset_id,
		"changing the result to option-2 re-picks a preset whose variant selects it, differing from option-1's",
	)
	var plain_row_id := "original/eventg01/30c-00000e52"
	_select_catalog_event_for_preset_test(player, plain_row_id)
	_check(not result_selector.visible, "a plain promoted row hides the result selector")
	_check(play.text == "Play", "a promoted plain analysis-group row shows Play in Playback view mode")


func _select_catalog_event_for_preset_test(player: KakyuEventPlayer, event_id: String) -> void:
	var tree: Tree = player.get("catalog_tree")
	var item := tree.get_root().get_first_child()
	while item != null:
		if str(item.get_metadata(0)) == event_id:
			item.select(0)
			player._on_catalog_event_selected()
			return
		item = item.get_next()
	_check(false, "preset selector fixture contains " + event_id)


func _catalog_preset_index_for_test(selector: OptionButton, preset_id: String) -> int:
	for index in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == preset_id:
			return index
	_check(false, "preset selector contains " + preset_id)
	return -1


func _catalog_result_index_for_test(selector: OptionButton, option_id: String) -> int:
	for index in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == option_id:
			return index
	_check(false, "result selector contains " + option_id)
	return -1


func _catalog_root_binding_observation(player: KakyuEventPlayer) -> Dictionary:
	var observation := {}
	for field in ["_state", "_reader", "_resolver", "_content_set", "_selected_entry", "_document", "_preview_event_session", "_preview_result_status", "_preview_result_offset", "_preview_messages", "_preview_mmo_name", "_preview_foreground_mmo_name", "_preview_ax_name", "_preview_bgm_name", "_preview_voice_name", "_preview_effect_name", "_choice_projection", "_continuation_offset", "_continuation_context", "_catalog_playback_request", "_catalog_playback_active", "_view_mode"]:
		var value: Variant = player.get(field)
		observation[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	observation["state_values"] = player.get("_state").snapshot()
	observation["reader_open"] = player.get("_reader").is_open()
	observation["status_label"] = (player.get("status_label") as Label).text
	observation["message_label"] = (player.get("_preview_message_label") as Label).text
	var surface: Image = player.get("_preview_surface_compositor").get_surface_copy(0)
	observation["surface_pixels"] = surface.get_data() if surface != null else PackedByteArray()
	return observation


func _cleanup() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
