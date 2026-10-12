extends "res://tools/content_suite/cli_script.gd"

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")

const SOURCE_ARCHIVE := "mes.arc"
const INPUT_DATE := 401
const OUTPUT_DATE := 402
const CASES := [
	{"entry": "A_PROMIS.MES", "intro": 0x2036, "boundary": 0x2091, "resume": 0x2096, "writer": 0x209B, "field": 215, "choice_boundary": 0x2C6B, "choice_resume": 0x2C70, "location_field": 119, "accepted_dialogues": 3, "accepted_return": 0x5BF7},
	{"entry": "B_PROMIS.MES", "intro": 0x253A, "boundary": 0x2591, "resume": 0x2596, "writer": 0x259B, "field": 233, "choice_boundary": 0x2F88, "choice_resume": 0x2F8D, "location_field": 209, "accepted_dialogues": 4, "accepted_return": 0x5036},
	{"entry": "C_PROMIS.MES", "intro": 0x1B97, "boundary": 0x1C0B, "resume": 0x1C10, "writer": 0x1C15, "field": 225, "choice_boundary": 0x2655, "choice_resume": 0x265A, "location_field": 169, "accepted_dialogues": 3, "accepted_return": 0x463E},
	{"entry": "D_PROMIS.MES", "intro": 0x1CD0, "boundary": 0x1D2D, "resume": 0x1D32, "writer": 0x1D37, "field": 237, "choice_boundary": 0x2726, "choice_resume": 0x272B, "location_field": 229, "accepted_dialogues": 3, "accepted_return": 0x4768},
	{"entry": "E_PROMIS.MES", "intro": 0x1D50, "boundary": 0x1DBA, "resume": 0x1DBF, "writer": 0x1DC4, "field": 217, "choice_boundary": 0x2817, "choice_resume": 0x281C, "location_field": 129, "accepted_dialogues": 3, "accepted_return": 0x4866},
	{"entry": "F_PROMIS.MES", "intro": 0x1DDE, "boundary": 0x1E3F, "resume": 0x1E44, "writer": 0x1E49, "field": 213, "choice_boundary": 0x289B, "choice_resume": 0x28A0, "location_field": 109, "accepted_dialogues": 3, "accepted_return": 0x48C8},
	{"entry": "G_PROMIS.MES", "intro": 0x2648, "boundary": 0x269D, "resume": 0x26A2, "writer": 0x26A7, "field": 221, "choice_boundary": 0x3114, "choice_resume": 0x3119, "location_field": 149, "accepted_dialogues": 3, "accepted_return": 0x51D5},
	{"entry": "H_PROMIS.MES", "intro": 0x1D7D, "boundary": 0x1DDC, "resume": 0x1DE1, "writer": 0x1DE6, "field": 227, "choice_boundary": 0x2855, "choice_resume": 0x285A, "location_field": 179, "accepted_dialogues": 5, "accepted_return": 0x4960},
	{"entry": "I_PROMIS.MES", "intro": 0x2554, "boundary": 0x25C4, "resume": 0x25C9, "writer": 0x25CE, "field": 219, "choice_boundary": 0x3039, "choice_resume": 0x303E, "location_field": 139, "accepted_dialogues": 3, "accepted_return": 0x5168},
	{"entry": "J_PROMIS.MES", "intro": 0x1DBB, "boundary": 0x1E12, "resume": 0x1E17, "writer": 0x1E1C, "field": 235, "choice_boundary": 0x281D, "choice_resume": 0x2822, "location_field": 219, "accepted_dialogues": 3, "accepted_return": 0x48C2},
	{"entry": "K_PROMIS.MES", "intro": 0x21CF, "boundary": 0x221A, "resume": 0x221F, "writer": 0x2224, "field": 229, "choice_boundary": 0x2C9B, "choice_resume": 0x2CA0, "location_field": 189, "accepted_dialogues": 3, "accepted_return": 0x4E1E},
	{"entry": "L_PROMIS.MES", "intro": 0x1C13, "boundary": 0x1C72, "resume": 0x1C77, "writer": 0x1C7C, "field": 231, "choice_boundary": 0x26F5, "choice_resume": 0x26FA, "location_field": 199, "accepted_dialogues": 5, "accepted_return": 0x4838},
]


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var elfimage_root := ProjectSettings.globalize_path(str(arguments[0]))
	var mes_path := elfimage_root.path_join(SOURCE_ARCHIVE)
	if not FileAccess.file_exists(mes_path):
		_fail("Original mes.arc is unavailable.")
		return
	var source_hash := FileAccess.get_sha256(mes_path)
	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.open_content_set(elfimage_root)
	var start_button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/StartEvent")
	var continue_button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/Continue")
	var legacy_date_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/KnownStateFields/LegacyDateEdit")
	var promise_location_label: Label = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateButtons/PromiseLocationLabel")
	var promise_location_edit: SpinBox = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateButtons/PromiseLocationEdit")
	var apply_promise_location: Button = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateButtons/ApplyPromiseLocation")
	var status_label: Label = player.get_node("Margin/Layout/StatusLabel")
	var preview_message_label: Label = player.get("_preview_message_label")
	var failures: Array[String] = []
	var reports: Array[String] = []

	player.load_entry("A_PROMIS.MES")
	legacy_date_edit.value = 230
	player.apply_quick_state()
	if not start_button.disabled or not start_button.tooltip_text.contains("valid legacy date"):
		failures.append("invalid legacy date did not keep the isolated PROMIS route disabled")
	var rollover_cases := {
		131: 201, 228: 301, 331: 401, 430: 501, 531: 601, 630: 701,
		731: 801, 831: 901, 930: 1001, 1031: 1101, 1130: 1201, 1231: 1301,
	}
	for input_date in rollover_cases:
		legacy_date_edit.value = int(input_date)
		player.apply_quick_state()
		var rollover_anchor: Dictionary = player.confirmed_event_start()
		var rollover_validation: Dictionary = player._validate_promise_date_route(rollover_anchor)
		if (
			not rollover_validation.get("ok", false)
			or int(rollover_validation.get("next_date", -1)) != int(rollover_cases[input_date])
		):
			failures.append("A_PROMIS.MES rejected audited month-end date %04d: %s" % [
				int(input_date),
				str(rollover_validation.get("error", "unexpected next date")),
			])

	for specification in CASES:
		player.reset_state()
		player.load_entry(str(specification.entry))
		legacy_date_edit.value = INPUT_DATE
		player.apply_quick_state()
		var anchor: Dictionary = player.confirmed_event_start()
		var validation: Dictionary = player._validate_promise_date_route(anchor)
		if (
			str(player.get("_selected_entry")) != str(specification.entry)
			or str((player.get("_document") as Dictionary).get("source", {}).get("resolved_source", "")) != "original_arc"
			or start_button.disabled
			or start_button.text != "Start PROMIS Schedule"
			or not validation.get("ok", false)
			or int(anchor.get("offset", -1)) != int(specification.intro)
			or int(anchor.get("writer", -1)) != int(specification.writer)
			or int(anchor.get("location_field", -1)) != int(specification.location_field)
			or promise_location_label.text != "PROMIS location g[%d]" % int(specification.location_field)
			or not promise_location_edit.editable
			or apply_promise_location.disabled
		):
			failures.append("%s did not expose its validated isolated date start" % str(specification.entry))
			continue

		player.start_event()
		var state = player.get("_state")
		var dialogue_boundaries := 0
		for _step in range(32):
			if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
				break
			dialogue_boundaries += 1
			player.advance()
		if (
			str(player.get("_preview_event_session")) != "promise_date"
			or int(player.get("_continuation_offset")) != int(specification.resume)
			or str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "shared_library"
			or int((player.get("_continuation_context") as Dictionary).get("routine_id", -1)) != 24
			or continue_button.disabled
			or state.read_value("state_u16", 9) != 1
			or state.read_value("state_u16", 10) != INPUT_DATE
		):
			failures.append(
				"%s did not stop at its exact routine-24 continuation after %d dialogue boundaries: session=%s status=%s@0x%X continuation=0x%X/%s/r%d disabled=%s state9=%d state10=%d"
				% [
					str(specification.entry),
					dialogue_boundaries,
					str(player.get("_preview_event_session")),
					str(player.get("_preview_result_status")),
					int(player.get("_preview_result_offset")),
					int(player.get("_continuation_offset")),
					str((player.get("_continuation_context") as Dictionary).get("kind", "")),
					int((player.get("_continuation_context") as Dictionary).get("routine_id", -1)),
					str(continue_button.disabled),
					state.read_value("state_u16", 9),
					state.read_value("state_u16", 10),
				]
			)
			continue

		player.advance()
		var post_write_dialogue_boundaries := 0
		for _step in range(64):
			if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
				break
			post_write_dialogue_boundaries += 1
			player.advance()
		var choice_projection: Dictionary = player.get("_choice_projection")
		if (
			str(player.get("_preview_result_status")) != "def_selection_boundary"
			or int(player.get("_preview_result_offset")) != int(specification.choice_boundary)
			or str(choice_projection.get("kind", "")) != "promise_time"
			or int(choice_projection.get("resume_offset", -1)) != int(specification.choice_resume)
			or int(choice_projection.get("state_index", -1)) != 21
			or (player.get("_preview_definitions") as Array).size() != 10
			or not (player.get("_preview_message_label") as Label).text.contains("> 1. ")
			or not (player.get("_preview_message_label") as Label).text.contains("[NO]")
			or not (player.get("_preview_footer_label") as Label).text.contains("L0: OK/NO/GATE")
		):
			failures.append("%s did not expose its exact ten-option original time choice" % str(specification.entry))
			continue
		player.confirm_choice(0)
		var post_choice_boundaries := 0
		for _step in range(128):
			if int(player.get("_continuation_offset")) < 0:
				break
			post_choice_boundaries += 1
			player.advance()
		var completion_label: Label = player.get("_preview_message_label")
		var choice_footer: Label = player.get("_preview_footer_label")
		var looped_choice_projection: Dictionary = player.get("_choice_projection")
		if (
			str(player.get("_preview_result_status")) != "def_selection_boundary"
			or int(player.get("_preview_result_offset")) != int(specification.choice_boundary)
			or str(looped_choice_projection.get("kind", "")) != "promise_time"
			or post_choice_boundaries != 2
			or state.read_value("state_u16", 21) != 1
			or state.read_value("state_u16", 10) != OUTPUT_DATE
			or state.read_value("banked_u16", int(specification.field), 0) != OUTPUT_DATE
			or bool(player.get("_preview_event_complete"))
			or bool(player.get("_preview_completion_shown"))
			or not completion_label.text.contains("> 1. ")
			or completion_label.text.split("\n").size() != 3
			or not choice_footer.text.contains("option 1/10")
			or (player.get("_preview_definitions") as Array).size() != 10
		):
			failures.append(
				"%s did not reproduce its empty-sandbox time rejection loop after %d post-write dialogue and %d post-choice boundaries: status=%s@0x%X continuation=0x%X state21=%d state10=%d field%d=%d complete=%s/%s label=%s"
				% [
					str(specification.entry),
					post_write_dialogue_boundaries,
					post_choice_boundaries,
					str(player.get("_preview_result_status")),
					int(player.get("_preview_result_offset")),
					int(player.get("_continuation_offset")),
					state.read_value("state_u16", 21),
					state.read_value("state_u16", 10),
					int(specification.field),
					state.read_value("banked_u16", int(specification.field), 0),
					str(player.get("_preview_event_complete")),
					str(player.get("_preview_completion_shown")),
					completion_label.text.replace("\n", " / "),
				]
			)
			continue

		promise_location_edit.value = 2
		player._on_apply_promise_location_pressed()
		if (
			state.read_value("global_u8", int(specification.location_field)) != 2
			or not (player.get_node("Margin/Layout/StatusLabel") as Label).text.contains("audited OK/NO/GATE status")
			or not (player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/Sandbox/StateJson") as TextEdit).text.contains("global_u8")
		):
			failures.append("%s did not apply its isolated selected-location field" % str(specification.entry))
			continue
		player.start_event()
		for _step in range(32):
			if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
				break
			player.advance()
		if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "shared_library":
			failures.append("%s accepted-location restart did not reach routine 24" % str(specification.entry))
			continue
		player.advance()
		for _step in range(64):
			if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
				break
			player.advance()
		if (
			str((player.get("_choice_projection") as Dictionary).get("kind", "")) != "promise_time"
			or not (player.get("_preview_message_label") as Label).text.contains("> 1. ")
			or not (player.get("_preview_message_label") as Label).text.contains("[OK]")
			or not (player.get("_preview_footer_label") as Label).text.contains("L2: OK/NO/GATE")
		):
			failures.append("%s accepted-location restart did not return to the time choice" % str(specification.entry))
			continue
		state.write_value("global_u8", 610, 0)
		var matrix_choice_state: Dictionary = state.snapshot()
		var matrix_choice_definitions: Array = (player.get("_preview_definitions") as Array).duplicate(true)
		var matrix_choice_projection: Dictionary = (player.get("_choice_projection") as Dictionary).duplicate(true)
		player.confirm_choice(0)
		var accepted_boundaries := 0
		var accepted_write_boundary := -1
		for _step in range(32):
			if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
				break
			accepted_boundaries += 1
			player.advance()
			if (
				accepted_write_boundary < 0
				and state.read_value("global_u8", 610) == 1
				and state.read_value("state_u16", 19) == 900
			):
				accepted_write_boundary = accepted_boundaries
		if (
			accepted_boundaries != int(specification.accepted_dialogues)
			or accepted_write_boundary < 0
			or state.read_value("global_u8", 610) != 1
			or state.read_value("banked_u16", int(specification.field) + 1, 0) != 900
			or state.read_value("state_u16", 19) != 0
			or str(player.get("_preview_result_status")) != "script_return"
			or int(player.get("_preview_result_offset")) != int(specification.accepted_return)
			or not (player.get("_choice_projection") as Dictionary).is_empty()
			or bool(player.get("_preview_event_complete"))
			or not status_label.text.contains("outer caller remains unresolved")
			or not preview_message_label.text.contains("original outer caller is not simulated")
		):
			failures.append(
				"%s did not complete its accepted option-one prefix: boundaries=%d transient_write_boundary=%d g610=%d final_hhmm=%d status=%s@0x%X context=%s"
				% [
					str(specification.entry),
					accepted_boundaries,
					accepted_write_boundary,
					state.read_value("global_u8", 610),
					state.read_value("state_u16", 19),
					str(player.get("_preview_result_status")),
					int(player.get("_preview_result_offset")),
					str((player.get("_continuation_context") as Dictionary).get("kind", "")),
				]
			)
			continue
		var matrix_failed := false
		for option_index in range(1, 10):
			var option_number := option_index + 1
			var option_hhmm := 800 + option_number * 100
			var option_flag := 609 + option_number
			state.restore(matrix_choice_state)
			state.write_value("global_u8", option_flag, 0)
			if str(specification.entry) == "A_PROMIS.MES" and option_number >= 8:
				state.write_value("global_u8", 1060, 1)
			player.set("_preview_definitions", matrix_choice_definitions.duplicate(true))
			player.set("_choice_projection", matrix_choice_projection.duplicate(true))
			player.set("_choice_index", option_index)
			player.confirm_choice(option_index)
			var option_boundaries := 0
			var option_write_boundary := -1
			for _step in range(64):
				if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
					break
				option_boundaries += 1
				player.advance()
				if (
					option_write_boundary < 0
					and state.read_value("global_u8", option_flag) == 1
					and state.read_value("state_u16", 19) == option_hhmm
				):
					option_write_boundary = option_boundaries
			if (
				option_boundaries != int(specification.accepted_dialogues)
				or option_write_boundary != 1
				or state.read_value("global_u8", option_flag) != 1
				or state.read_value("banked_u16", int(specification.field) + 1, 0) != option_hhmm
				or state.read_value("state_u16", 19) != 0
				or str(player.get("_preview_result_status")) != "script_return"
				or int(player.get("_preview_result_offset")) != int(specification.accepted_return)
				or not (player.get("_choice_projection") as Dictionary).is_empty()
				or bool(player.get("_preview_event_complete"))
				or not status_label.text.contains("outer caller remains unresolved")
			):
				failures.append(
					"%s option %d did not complete the accepted matrix route: boundaries=%d write=%d flag%d=%d hhmm=%d aux%d=%d status=%s@0x%X complete=%s"
					% [
						str(specification.entry),
						option_number,
						option_boundaries,
						option_write_boundary,
						option_flag,
						state.read_value("global_u8", option_flag),
						state.read_value("state_u16", 19),
						int(specification.field) + 1,
						state.read_value("banked_u16", int(specification.field) + 1, 0),
						str(player.get("_preview_result_status")),
						int(player.get("_preview_result_offset")),
						str(player.get("_preview_event_complete")),
					]
				)
				matrix_failed = true
				break
		if matrix_failed:
			continue
		var a_evening_gate_report := ""
		if str(specification.entry) == "A_PROMIS.MES":
			var a_gate_failed := false
			for option_index in range(7, 10):
				var option_number := option_index + 1
				var option_hhmm := 800 + option_number * 100
				var option_flag := 609 + option_number
				state.restore(matrix_choice_state)
				state.write_value("global_u8", 1060, 0)
				state.write_value("banked_u16", 201, 99, 0)
				state.write_value("global_u8", option_flag, 0)
				player.set("_preview_definitions", matrix_choice_definitions.duplicate(true))
				player.set("_choice_projection", matrix_choice_projection.duplicate(true))
				player.set("_choice_index", option_index)
				player.confirm_choice(option_index)
				var low_gate_boundaries := 0
				for _step in range(32):
					if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
						break
					low_gate_boundaries += 1
					player.advance()
				if (
					low_gate_boundaries != 2
					or str(player.get("_preview_result_status")) != "def_selection_boundary"
					or int(player.get("_preview_result_offset")) != int(specification.choice_boundary)
					or str((player.get("_choice_projection") as Dictionary).get("kind", "")) != "promise_time"
					or state.read_value("global_u8", 1060) != 0
					or state.read_value("global_u8", option_flag) != 0
				):
					failures.append(
						"A_PROMIS.MES option %d did not reproduce the field-201 low gate: boundaries=%d status=%s@0x%X latch=%d flag%d=%d"
						% [
							option_number,
							low_gate_boundaries,
							str(player.get("_preview_result_status")),
							int(player.get("_preview_result_offset")),
							state.read_value("global_u8", 1060),
							option_flag,
							state.read_value("global_u8", option_flag),
						]
					)
					a_gate_failed = true
					break

				state.restore(matrix_choice_state)
				state.write_value("state_u16", 7, 824)
				state.write_value("global_u8", int(specification.location_field), 14)
				state.write_value("global_u8", 1060, 0)
				state.write_value("banked_u16", 201, 100, 0)
				state.write_value("global_u8", option_flag, 0)
				player.set("_preview_definitions", matrix_choice_definitions.duplicate(true))
				player.set("_choice_projection", matrix_choice_projection.duplicate(true))
				player.set("_choice_index", option_index)
				player.confirm_choice(option_index)
				var special_date_boundaries := 0
				for _step in range(32):
					if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
						break
					special_date_boundaries += 1
					player.advance()
				if (
					special_date_boundaries != 2
					or str(player.get("_preview_result_status")) != "def_selection_boundary"
					or int(player.get("_preview_result_offset")) != int(specification.choice_boundary)
					or state.read_value("global_u8", 1060) != 0
					or state.read_value("global_u8", option_flag) != 0
				):
					failures.append(
						"A_PROMIS.MES option %d did not keep the 0824/location-14 gate ahead of the high threshold: boundaries=%d status=%s@0x%X latch=%d flag%d=%d"
						% [
							option_number,
							special_date_boundaries,
							str(player.get("_preview_result_status")),
							int(player.get("_preview_result_offset")),
							state.read_value("global_u8", 1060),
							option_flag,
							state.read_value("global_u8", option_flag),
						]
					)
					a_gate_failed = true
					break

				state.restore(matrix_choice_state)
				state.write_value("global_u8", 1060, 0)
				state.write_value("banked_u16", 201, 100, 0)
				state.write_value("global_u8", option_flag, 0)
				player.set("_preview_definitions", matrix_choice_definitions.duplicate(true))
				player.set("_choice_projection", matrix_choice_projection.duplicate(true))
				player.set("_choice_index", option_index)
				player.confirm_choice(option_index)
				var high_gate_boundaries := 0
				for _step in range(64):
					if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
						break
					high_gate_boundaries += 1
					player.advance()
				if (
					high_gate_boundaries != 8
					or str(player.get("_preview_result_status")) != "def_selection_boundary"
					or int(player.get("_preview_result_offset")) != int(specification.choice_boundary)
					or str((player.get("_choice_projection") as Dictionary).get("kind", "")) != "promise_time"
					or state.read_value("global_u8", 1060) != 1
					or state.read_value("global_u8", option_flag) != 0
				):
					failures.append(
						"A_PROMIS.MES option %d did not reproduce the field-201 high gate/latch retry: boundaries=%d status=%s@0x%X latch=%d flag%d=%d"
						% [
							option_number,
							high_gate_boundaries,
							str(player.get("_preview_result_status")),
							int(player.get("_preview_result_offset")),
							state.read_value("global_u8", 1060),
							option_flag,
							state.read_value("global_u8", option_flag),
						]
					)
					a_gate_failed = true
					break

				player.confirm_choice(option_index)
				var post_latch_boundaries := 0
				var post_latch_write_boundary := -1
				for _step in range(32):
					if str((player.get("_continuation_context") as Dictionary).get("kind", "")) != "dialogue":
						break
					post_latch_boundaries += 1
					player.advance()
					if (
						post_latch_write_boundary < 0
						and state.read_value("global_u8", option_flag) == 1
						and state.read_value("state_u16", 19) == option_hhmm
					):
						post_latch_write_boundary = post_latch_boundaries
				if (
					post_latch_boundaries != int(specification.accepted_dialogues)
					or post_latch_write_boundary != 1
					or state.read_value("global_u8", option_flag) != 1
					or state.read_value("banked_u16", int(specification.field) + 1, 0) != option_hhmm
					or state.read_value("state_u16", 19) != 0
					or str(player.get("_preview_result_status")) != "script_return"
					or int(player.get("_preview_result_offset")) != int(specification.accepted_return)
				):
					failures.append(
						"A_PROMIS.MES option %d did not accept after its high-gate retry: boundaries=%d write=%d flag%d=%d aux%d=%d status=%s@0x%X"
						% [
							option_number,
							post_latch_boundaries,
							post_latch_write_boundary,
							option_flag,
							state.read_value("global_u8", option_flag),
							int(specification.field) + 1,
							state.read_value("banked_u16", int(specification.field) + 1, 0),
							str(player.get("_preview_result_status")),
							int(player.get("_preview_result_offset")),
						]
					)
					a_gate_failed = true
					break
			if a_gate_failed:
				continue
			a_evening_gate_report = "/A_gate16..18=low2+date2+high8+latch_retry+accept"
		reports.append("%s:0x%X/dialogue%d->r24@0x%X/resume0x%X/write%d@0x%X=%04d/dialogue%d/choice0x%X=1/reject%d/choice_loop/location_g%d=2/matrix10/dialogue%d/write@1/flags610..619/aux%d=0900..1800/return0x%X/final_hhmm0" % [
			str(specification.entry),
			int(specification.intro),
			dialogue_boundaries,
			int(specification.boundary),
			int(specification.resume),
			int(specification.field),
			int(specification.writer),
			OUTPUT_DATE,
			post_write_dialogue_boundaries,
			int(specification.choice_boundary),
			post_choice_boundaries,
			int(specification.location_field),
			accepted_boundaries,
			int(specification.field) + 1,
			int(specification.accepted_return),
		] + a_evening_gate_report)

	if FileAccess.get_sha256(mes_path) != source_hash:
		failures.append("original mes.arc changed during Event Player PROMIS validation")
	player.queue_free()
	if not failures.is_empty():
		_fail("; ".join(failures))
		return
	print("PASS: Event Player PROMIS isolated scheduling routes %s month_end_cases=12 terminal_1231=1301 accepted_time_matrix=120 source_unchanged=true outer_callers=unresolved location_state=resolved" % " | ".join(reports))
	quit(0)
