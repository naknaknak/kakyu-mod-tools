extends "res://tools/content_suite/cli_script.gd"

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")

const SOURCE_ENTRY := "DEF_MAIN.MES"
const INTRO_OFFSET := "0x203"


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var elfimage_root := ProjectSettings.globalize_path(str(arguments[0]))
	var mes_path := elfimage_root.path_join("mes.arc")
	if not FileAccess.file_exists(mes_path):
		_fail("Original mes.arc is unavailable.")
		return
	var source_hash := FileAccess.get_sha256(mes_path)
	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.open_content_set(elfimage_root)
	player.load_entry(SOURCE_ENTRY)
	var status_label: Label = player.get_node("Margin/Layout/StatusLabel")
	var start_button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/StartEvent")
	if (
		str(player.get("_selected_entry")) != SOURCE_ENTRY
		or str((player.get("_document") as Dictionary).get("entry_sha256", "")) != "f2012ce5d90f60a5d1ca8190e03571341c0384c2d3d96e9aec2b3ab949db0ef0"
		or not status_label.text.contains("loaded from original_arc")
		or start_button.disabled
		or start_button.text != "Start Isolated DEF Body"
	):
		player.queue_free()
		_fail("Event Player did not expose the hash-bound isolated DEF26 body start.")
		return
	player.start_event()
	var intro_edit: LineEdit = player.get_node("Margin/Layout/MainSplit/Right/RunBar/IntroEdit")
	var output: RichTextLabel = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/Output")
	var footer: Label = player.get("_preview_footer_label")
	var continue_button: Button = player.get("continue_button")
	if (
		intro_edit.text.to_upper() != INTRO_OFFSET.to_upper()
		or not output.text.contains("native_record_boundary")
		or str(player.get("_preview_event_session")) != "def26_isolated_body"
		or int(player.get("_continuation_offset")) != 0x0216
		or str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "def26_native_records_omitted"
		or str((player.get("_continuation_context") as Dictionary).get("native_record_policy", "")) != "omit_bounded"
		or continue_button.disabled
		or continue_button.text != "Continue (Omit Body Records)"
		or not footer.text.contains("Continue explicitly omits unresolved native record effects")
	):
		player.queue_free()
		_fail("Isolated DEF26 start did not expose its explicit record-effects-omitted continuation.")
		return
	player.advance()
	var trace_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/TraceTree")
	var trace_root := trace_tree.get_root()
	var omitted_count := 0
	if trace_root != null:
		for item in trace_root.get_children():
			if item.get_text(3).contains("native_record_effects_omitted"):
				omitted_count += 1
	var failures: Array[String] = []
	if int(player.get("_continuation_offset")) >= 0:
		failures.append("isolated DEF26 continuation remained active after return")
	if not output.text.contains("script_return") or not output.text.contains("0x42C"):
		failures.append("isolated DEF26 continuation did not reach return 0x42C")
	if trace_root == null or trace_root.get_child_count() != 52 or omitted_count != 31:
		failures.append("remaining DEF26 route did not retain 20 markers, 31 omitted record dispatches, and one return")
	if not (player.get("_state") as KakyuMesSandboxState).to_records().is_empty():
		failures.append("isolated DEF26 record audit changed sandbox state")
	if FileAccess.get_sha256(mes_path) != source_hash:
		failures.append("source mes.arc changed during Event Player validation")
	player.queue_free()
	if not failures.is_empty():
		_fail("; ".join(failures))
		return
	print("PASS: Event Player DEF26 isolated start=0x203 first_stop=0x208:4_records resume=0x216 omitted_remaining_records=31 trace=52 return=0x42C messages=0 state_diff=none source_unchanged=true")
	quit(0)
