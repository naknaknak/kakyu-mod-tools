extends "res://tools/content_suite/cli_script.gd"

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")

const ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const CASES := [
	{
		"entry": "44C.MES",
		"entry_sha256": "49b5ae569923d6b0e58bf6bf64786f2e96fe9de00c9bad56cd450cb4a487d0ce",
		"intro": 0xC52A,
		"promise_call": 0xC6EC,
	},
	{
		"entry": "L_HOTEL2.MES",
		"entry_sha256": "5ed3ba5238949f180a8da82961df9d9fe6b8bf818dbc7cf464c84ac38de85e49",
		"intro": 0x421C,
		"promise_call": 0x43EB,
	},
]


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0]))
	var archive_path := source_root.path_join("mes.arc")
	if not FileAccess.file_exists(archive_path) or FileAccess.get_sha256(archive_path) != ARCHIVE_SHA256:
		_fail("The authoritative mes.arc is unavailable or has an unexpected hash.")
		return
	var source_before := FileAccess.get_sha256(archive_path)
	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	var failures: Array[String] = []
	var reports: Array[String] = []
	for case in CASES:
		for choice_index in range(2):
			player.reset_state()
			player.load_entry(str(case.entry))
			var document: Dictionary = player.get("_document")
			var button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/StartEvent")
			if (
				str(player.get("_selected_entry")) != str(case.entry)
				or str(document.get("entry_sha256", "")) != str(case.entry_sha256)
				or button.disabled
				or button.text != "Start Nested Dialogue"
			):
				failures.append("%s did not expose its hash-bound nested start" % str(case.entry))
				continue
			var readiness: Dictionary = player._nested_promise_route_readiness(player.confirmed_event_start())
			if not readiness.get("ok", false):
				failures.append("%s nested route validation failed: %s" % [str(case.entry), str(readiness)])
				continue
			player.start_event()
			var state: KakyuMesSandboxState = player.get("_state")
			var definitions: Array = player.get("_preview_definitions")
			var projection: Dictionary = player.get("_choice_projection")
			var trace_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/TraceTree")
			var message_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/MessageTree")
			var script_call_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/ScriptCallTree")
			var saw_root_trace := false
			var saw_talk_trace := false
			var trace_item := trace_tree.get_root().get_first_child()
			while trace_item != null:
				var coordinate_text := trace_item.get_text(1)
				saw_root_trace = saw_root_trace or coordinate_text.begins_with("%s · " % str(case.entry))
				saw_talk_trace = saw_talk_trace or coordinate_text.begins_with("L_TALK30.MES · ")
				trace_item = trace_item.get_next()
			var saw_root_message := false
			var saw_talk_message := false
			var message_item := message_tree.get_root().get_first_child()
			while message_item != null:
				var source_text := message_item.get_text(1)
				saw_root_message = saw_root_message or source_text.begins_with("%s · " % str(case.entry))
				saw_talk_message = saw_talk_message or source_text.begins_with("L_TALK30.MES · ")
				message_item = message_item.get_next()
			var pending_call := script_call_tree.get_root().get_first_child()
			if (
				str(player.get("_preview_event_session")) != "nested_promise"
				or str(player.get("_preview_result_status")) != "def_selection_boundary"
				or int(player.get("_preview_result_offset")) != 0x0561
				or definitions.size() != 2
				or str(projection.get("kind", "")) != "nested_promise"
				or state.read_value("banked_u16", 209, 0) != 21
				or state.read_value("global_u8", 1941) != 1
				or not str(player.get("_preview_footer_label").text).contains("Up/Down")
				or not saw_root_trace
				or not saw_talk_trace
				or not saw_root_message
				or not saw_talk_message
				or pending_call == null
				or pending_call.get_text(1) != "%s · 0x%08X" % [str(case.entry), int(readiness.route.talk_call)]
				or pending_call.get_text(2) != "L_TALK30.MES"
				or not pending_call.get_text(3).contains("not returned")
			):
				failures.append(
					"%s did not reach the audited L_TALK30 choice boundary (root_trace=%s talk_trace=%s root_message=%s talk_message=%s call=%s|%s|%s)"
					% [
						str(case.entry),
						str(saw_root_trace),
						str(saw_talk_trace),
						str(saw_root_message),
						str(saw_talk_message),
						"none" if pending_call == null else pending_call.get_text(1),
						"none" if pending_call == null else pending_call.get_text(2),
						"none" if pending_call == null else pending_call.get_text(3),
					]
				)
				continue
			var key_event := InputEventKey.new()
			key_event.keycode = KEY_1 if choice_index == 0 else KEY_2
			key_event.pressed = true
			player.send_preview_input(key_event, Vector2.ZERO)
			var returned_call := script_call_tree.get_root().get_first_child()
			var expected_return := 0x0284 if choice_index == 0 else 0x02C1
			if (
				str(player.get("_preview_result_status")) != "script_dispatch_boundary"
				or int(player.get("_preview_result_offset")) != int(case.promise_call)
				or not bool(player.get("_nested_promise_reached_boundary"))
				or not (player.get("_choice_projection") as Dictionary).is_empty()
				or (player.get("_preview_messages") as Array).size() != 2
				or state.read_value("global_u8", 2006) != 1
				or not str(player.get("status_label").text).contains("PROMIS.MES boundary")
				or returned_call == null
				or not returned_call.get_text(3).contains("returned 0x%08X" % expected_return)
			):
				failures.append(
					"%s choice %d did not restore its caller at the audited PROMIS boundary (call=%s)"
					% [
						str(case.entry),
						choice_index,
						"none" if returned_call == null else returned_call.get_text(3),
					]
				)
				continue
			player.step_preview_message(1)
			if not str(player.get("_preview_footer_label").text).contains("L_PROMIS.MES BOUNDARY REACHED"):
				failures.append("%s choice %d game frame did not expose the terminal PROMIS boundary" % [str(case.entry), choice_index])
				continue
			reports.append("%s#%d:0x%X" % [str(case.entry), choice_index, int(case.promise_call)])

	var source_after := FileAccess.get_sha256(archive_path)
	player.queue_free()
	if not failures.is_empty():
		_fail(" | ".join(failures))
		return
	if source_after != source_before or reports.size() != 4:
		_fail("Nested Event Player validation changed its source or case count.")
		return
	print("EVENT_PLAYER_NESTED_PROMISE cases=%d routes=%s source_unchanged=true gameplay_saves_unchanged=true" % [
		reports.size(),
		" | ".join(reports),
	])
	quit(0)
