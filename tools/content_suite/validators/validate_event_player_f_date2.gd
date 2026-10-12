extends "res://tools/content_suite/cli_script.gd"

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")

const SOURCE_ENTRY := "F_DATE2.MES"
const ENTRY_SHA256 := "fe7dcb7d58b0974f19cdda918e3158860c1b230172640bec1a31cd933c0de07e"
const ANCHOR_INDEX := 187
const INTRO_OFFSET := 0x6768
const OUTER_DEFINITION_ID := 1
const BODY_OFFSET := 0x67BB
const TARGET_OFFSET := 0x67F1


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
	if (
		str(player.get("_selected_entry")) != SOURCE_ENTRY
		or str((player.get("_document") as Dictionary).get("entry_sha256", "")) != ENTRY_SHA256
	):
		player.queue_free()
		_fail("Event Player did not load the audited F_DATE2 entry.")
		return
	var address_tree: Tree = player.get_node("Margin/Layout/MainSplit/Sources/AddressTree")
	var address_root := address_tree.get_root()
	var source_item: TreeItem
	if address_root != null:
		for item in address_root.get_children():
			if (
				str(item.get_metadata(1)) == "address_entry"
				and int(item.get_metadata(2)) == ANCHOR_INDEX
				and int(item.get_metadata(0)) == INTRO_OFFSET
			):
				source_item = item
				break
	var preview_button: Button = player.get_node("Margin/Layout/MainSplit/Right/RunBar/PreviewFragment")
	var previous_button: Button = player.get_node("Margin/Layout/MainSplit/Sources/FragmentNavigation/PreviousFragment")
	var next_button: Button = player.get_node("Margin/Layout/MainSplit/Sources/FragmentNavigation/NextFragment")
	var previous_meaningful: Button = player.get_node("Margin/Layout/MainSplit/Sources/MeaningfulNavigation/PreviousMeaningful")
	var next_meaningful: Button = player.get_node("Margin/Layout/MainSplit/Sources/MeaningfulNavigation/NextMeaningful")
	if source_item == null:
		player.queue_free()
		_fail("F_DATE2 audited source-table row was not displayed.")
		return
	source_item.select(0)
	player.select_address()
	if (
		preview_button.disabled
		or preview_button.text != "Preview Row #0187"
		or not source_item.get_text(2).ends_with(" · 3 DEF")
	):
		player.queue_free()
		_fail(
			"F_DATE2 source-table row did not expose its screen-based preview action and first-stop summary "
			+ "(button=%s disabled=%s summary=%s)."
			% [preview_button.text, preview_button.disabled, source_item.get_text(2)]
		)
		return
	if (
		previous_button.disabled
		or next_button.disabled
		or previous_meaningful.disabled
		or next_meaningful.disabled
	):
		player.queue_free()
		_fail("F_DATE2 row #0187 did not expose both adjacent and content-stop directions.")
		return
	player._on_next_catalog_fragment_pressed()
	var next_source_item := address_tree.get_selected()
	if next_source_item == null or int(next_source_item.get_metadata(2)) != ANCHOR_INDEX + 1:
		player.queue_free()
		_fail("F_DATE2 Next Row did not preview adjacent row #0188.")
		return
	player._on_previous_meaningful_row_pressed()
	if (
		address_tree.get_selected() != source_item
		or int(player.get("_preview_source_row_index")) != ANCHOR_INDEX
	):
		player.queue_free()
		_fail("F_DATE2 Prev Hit did not return to DEF row #0187 without native-order inference.")
		return
	player._on_address_activated()
	var definitions: Array = player.get("_preview_definitions")
	var choice_projection: Dictionary = player.get("_choice_projection")
	if (
		str(player.get("_preview_result_status")) != "def_selection_boundary"
		or definitions.size() < 2
		or str(choice_projection.get("kind", "")) != "detached_def_preview"
		or int(definitions[1].get("definition_id", -1)) != OUTER_DEFINITION_ID
		or int(definitions[1].get("body_offset", -1)) != BODY_OFFSET
		or int(definitions[1].get("target_offset", -1)) != TARGET_OFFSET
	):
		var definition_coordinates: Array[String] = []
		for untyped_definition in definitions:
			var definition: Dictionary = untyped_definition
			definition_coordinates.append(
				"DEF%d=0x%X..0x%X"
				% [
					int(definition.get("definition_id", -1)),
					int(definition.get("body_offset", -1)),
					int(definition.get("target_offset", -1)),
				]
			)
		player.queue_free()
		_fail(
			"F_DATE2 did not expose its audited detached DEF 1 option "
			+ "(status=%s kind=%s definitions=[%s])."
			% [
				str(player.get("_preview_result_status")),
				str(choice_projection.get("kind", "")),
				", ".join(definition_coordinates),
			]
		)
		return
	var state_before: Dictionary = (player.get("_state") as KakyuMesSandboxState).snapshot()
	player._run_detached_definition_preview(1, choice_projection)
	var trace_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/TraceTree")
	var trace_root := trace_tree.get_root()
	var call_tree: Tree = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/ScriptCallTree")
	var call_root := call_tree.get_root()
	var external_def99_rows := 0
	var external_def99_source_rows := 0
	if trace_root != null:
		for item in trace_root.get_children():
			if item.get_text(3).contains("external DEF 99"):
				external_def99_rows += 1
				if item.get_text(1).begins_with("DEF_MAIN.MES · "):
					external_def99_source_rows += 1
	var output: RichTextLabel = player.get_node("Margin/Layout/MainSplit/Right/WorkTabs/ResultTabs/Output")
	var footer: Label = player.get("_preview_footer_label")
	var status_label: Label = player.get_node("Margin/Layout/StatusLabel")
	var failures: Array[String] = []
	if str(player.get("_preview_result_status")) != "detached_definition_complete":
		failures.append("detached F_DATE2 body did not reach its bounded return")
	if not str((player.get("_preview_entry_label") as Label).text).contains("source row #0187"):
		failures.append("F_DATE2 preview did not retain its selected source-table row identity")
	if (player.get("_preview_messages") as Array).size() != 3:
		failures.append("detached F_DATE2 body did not expose its three outer message projections")
	if int(player.get("_preview_detached_definition_id")) != OUTER_DEFINITION_ID:
		failures.append("detached F_DATE2 identity changed")
	if int(player.get("_continuation_offset")) != -1:
		failures.append("detached F_DATE2 incorrectly enabled caller continuation")
	if (player.get("_state") as KakyuMesSandboxState).snapshot() != state_before:
		failures.append("detached F_DATE2 changed the Event Player sandbox")
	if (
		trace_root == null
		or trace_root.get_child_count() != 8
		or external_def99_rows != 4
		or external_def99_source_rows != 4
	):
		failures.append("detached F_DATE2 trace did not retain its DEF 99 call/return envelope")
	if (
		call_root == null
		or call_root.get_child_count() != 1
		or not call_root.get_first_child().get_text(0).contains("DEF")
		or not call_root.get_first_child().get_text(1).contains("0x000067CD")
		or not call_root.get_first_child().get_text(2).contains("registered DEF 99")
		or not call_root.get_first_child().get_text(2).contains("DEF_MAIN.MES:0x1518")
		or not call_root.get_first_child().get_text(3).contains("0x000067D2")
	):
		failures.append("Script Calls did not expose the registered DEF call and resume coordinates")
	if not footer.text.contains("DETACHED DEF 2 COMPLETE"):
		failures.append("game frame did not label the detached body complete")
	if footer.text.contains("ﾂｷ") or not footer.text.contains(" · explicit tool preview · "):
		failures.append("game frame detached-preview separators are not valid Unicode")
	if not status_label.text.contains("complete with 3 messages"):
		failures.append("desktop status did not report the three collected messages")
	if not output.text.contains("Registered DEF composition:") or not output.text.contains("startup-registry"):
		failures.append("Summary did not expose explicit registered-DEF provenance")
	if FileAccess.get_sha256(mes_path) != source_hash:
		failures.append("source mes.arc changed during Event Player validation")
	player.queue_free()
	if not failures.is_empty():
		_fail("; ".join(failures))
		return
	print("PASS: Event Player F_DATE2 intro=0x6768 source_row=187 summary=3_DEF next_row=188 prev_hit=187 detached_DEF=1 body=0x67BB..0x67F1 registered_DEF=99 messages=2 trace=8 completion=script_return sandbox_unchanged=true source_unchanged=true")
	quit(0)
