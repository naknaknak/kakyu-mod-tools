extends "res://tools/content_suite/cli_script.gd"

const EventPlayerScene := preload("res://tools/content_suite/apps/event_player.tscn")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")

const INVALID_FRAGMENT_STATUSES := {
	"decode_error": true,
	"expression_error": true,
	"invalid_address_table_index": true,
	"invalid_start": true,
	"invalid_target": true,
	"invalid_write": true,
	"step_limit": true,
	"unsupported_opcode": true,
}

const CATALOGS := {
	"EVENTD06.MES": {
		"entry_sha256": "ce90c77ca8ca6dae38b236eb5dfc19ef1848083b433d86d9f49331968769c142",
		"entry_count": 67,
		"fragment_count": 66,
		"caller_entry": "10C.MES",
		"caller_offset": 0x5F77,
		"caller_resume": 0x5F87,
		"setup_start_coordinate": 0x0008,
		"setup_entry_offset": 0x0008,
		"setup_entry_index": 0,
		"setup_start_kind": "source_table_entry",
		"setup_first_effect": "fallthrough",
		# Core 0.377.0 (TD-56): +1 stored cell, global_i32[1], the argument the setup's
		# command 0x09 assigned before its routine-28 boundary (11 before).
		"setup_state_change_count": 12,
		"setup_final_state_change_count": 25,
		"setup_shared_routine": 28,
		"setup_shared_offset": 0x00E6,
		"setup_shared_resume": 0x00EB,
		"setup_native_offset": 0x0105,
		"setup_native_resume": 0x0110,
		"setup_native_record_count": 3,
		"setup_native_presentation_boundaries": [],
		"setup_extension_mmo": "D07.MMO",
		"setup_extension_terminals": [
			{"status": "shared_routine_boundary", "offset": 0x0C0E, "resume": 0x0C13, "routine_id": 21, "branch_global_u8_4000": 0},
			{"status": "shared_routine_boundary", "offset": 0x0C1E, "resume": 0x0C23, "routine_id": 28, "branch_global_u8_4000": 1},
		],
		# Core 0.377.0 (TD-56): the setup run takes the second declared terminal. Its
		# command-0x09 argument 1 reaches the first routine-28 call as the real selector,
		# whose arm sets global_u8[4000] to 1; the branch then skips the routine-21 call
		# at 0x0269 on the way and the later one at 0x0C0E, and the run stops before
		# routine 28 at 0x0C1E (before the feed: the default terminal, routine 21 at
		# 0x0C0E, [4000]=0). Both terminals stay declared in the catalog above.
		"setup_extension_terminal_status": "shared_routine_boundary",
		"setup_extension_terminal_offset": 0x0C1E,
		"setup_extension_terminal_routine": 28,
		"setup_mmo_followup_write": {"offset": 0x022D, "bank": 0, "index": 1, "value": 7},
		"setup_terminal_status": "shared_routine_boundary",
		"setup_terminal_offset": 0x0C0E,
		"setup_terminal_message_count": 0,
		"setup_expected_path": [
			"routine28@0xE6",
			"record@0x105->0x110",
			"routine28@0x2E0",
			"dialogue@0x4B8",
			"dialogue@0x53D",
			"dialogue@0x5E7",
			"dialogue@0x63C",
			"routine27@0x675",
			"routine25@0x681",
			"library_def26@0x1E22->0x686",
			"routine21@0x6BB",
			"dialogue@0x737",
			"dialogue@0x79A",
			"dialogue@0x943",
			"dialogue@0x998",
			"dialogue@0xA1C",
			"dialogue@0xA6F",
			"dialogue@0xAFB",
			"dialogue@0xB5F",
			"routine28@0xB83",
			"routine28@0xC1E",
		],
		"exe_audit_schema": "kakyu_ai5_mes_exe_audit/v106",
	},
	"EVENTD14.MES": {
		"entry_sha256": "4279a51fc9510d2442b537b9cf28613074da000d35c3c72ba9758dae63e1b24f",
		"entry_count": 66,
		"fragment_count": 65,
		"caller_entry": "12C.MES",
		"caller_offset": 0x1C23,
		"caller_resume": 0x1C33,
		"setup_start_coordinate": 0,
		"setup_entry_offset": 0x0008,
		"setup_entry_index": 0,
		"setup_start_kind": "audited_nested_call",
		"setup_first_effect": "bootstrap_transfer",
		"nested_start_coordinate": 0,
		"bootstrap_target": 0x0008,
		"bootstrap_entry_index": 0,
		"exe_audit_schema": "kakyu_ai5_mes_exe_audit/v106",
		# Core 0.377.0 (TD-56): +1 stored cell, global_i32[1] (12 before).
		"setup_state_change_count": 13,
		# Core 0.377.0 (TD-56): +2 stored cells (21 before): global_i32[1], the argument of
		# the last command 0x09 (47328), and global_u8[4000] = 0, written by the routine-28
		# arm that selector now picks.
		"setup_final_state_change_count": 23,
		"setup_shared_routine": 28,
		"setup_shared_offset": 0x014D,
		"setup_shared_resume": 0x0152,
		"setup_native_offset": 0x016C,
		"setup_native_resume": 0x0177,
		"setup_native_record_count": 3,
		"setup_reaches_event_choice": true,
		"setup_definition_calls": [
			{
				"offset": 0x032E,
				"resume": 0x0333,
				"definition_id": 21,
				"source": "DEF_MAIN.MES:0x10BD",
				"body_offset": 0x10C4,
				"end_offset": 0x1102,
			},
		],
		"route_definition_calls": [
			{"offset": 0x0DE9, "resume": 0x0DEE, "definition_id": 22, "source": "DEF_MAIN.MES:0x1102", "body_offset": 0x1109, "end_offset": 0x116E},
			{"offset": 0x1396, "resume": 0x139B, "definition_id": 22, "source": "DEF_MAIN.MES:0x1102", "body_offset": 0x1109, "end_offset": 0x116E},
			{"offset": 0x1476, "resume": 0x147B, "definition_id": 21, "source": "DEF_MAIN.MES:0x10BD", "body_offset": 0x10C4, "end_offset": 0x1102},
			{"offset": 0x1878, "resume": 0x187D, "definition_id": 22, "source": "DEF_MAIN.MES:0x1102", "body_offset": 0x1109, "end_offset": 0x116E},
			{"offset": 0x20DF, "resume": 0x20E4, "definition_id": 22, "source": "DEF_MAIN.MES:0x1102", "body_offset": 0x1109, "end_offset": 0x116E},
			{"offset": 0x23AC, "resume": 0x23B1, "definition_id": 22, "source": "DEF_MAIN.MES:0x1102", "body_offset": 0x1109, "end_offset": 0x116E},
			{"offset": 0x254E, "resume": 0x2553, "definition_id": 22, "source": "DEF_MAIN.MES:0x1102", "body_offset": 0x1109, "end_offset": 0x116E},
		],
		"route_native_record_boundaries": [
			{"offset": 0x13E1, "resume": 0x13F9, "record_count": 6},
		],
		"route_script_dispatches": [
			{"offset": 0x0ED4, "resume": 0x0EE1, "target": "D_PIC.MES"},
			{"offset": 0x1963, "resume": 0x1970, "target": "D_PIC.MES"},
			{"offset": 0x21CA, "resume": 0x21D7, "target": "D_PIC.MES"},
		],
		"route_terminal_status": "script_return",
		"route_terminal_offset": 0x256D,
		"route_choice_state_index": 21,
		"route_choice_values": [1, 2, 3],
		"route_completion_state_index": KakyuEventPlayerEvidence.EVENTD14_COMPLETION_STATE_INDEX,
		"setup_terminal_status": "def_selection_boundary",
		"setup_terminal_offset": KakyuEventPlayerEvidence.EVENTD14_CHOICE_BOUNDARY,
		"setup_expected_path": [
			"routine28@0x14D",
			"record@0x16C->0x177",
			"routine28@0x288",
			"def21@0x32E->0x333",
			"dialogue@0x37A",
			"dialogue@0x3EA",
			"dialogue@0x44B",
			"dialogue@0x4C5",
			"dialogue@0x504",
			"dialogue@0x534",
			"dialogue@0x573",
			"dialogue@0x5E7",
			"dialogue@0x64C",
			"dialogue@0x6CA",
			"dialogue@0x731",
			"dialogue@0x79B",
			"dialogue@0x7E4",
			"dialogue@0x85E",
			"choice@0x942:0@0x8A0->0x8CA,1@0x8CF->0x8FD,2@0x902->0x938",
		],
	},
}


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0]))
	var mes_path := source_root.path_join("mes.arc")
	if not DirAccess.dir_exists_absolute(source_root) or not FileAccess.file_exists(mes_path):
		_fail("ELFIMAGE/mes.arc is unavailable.")
		return
	var source_sha := FileAccess.get_sha256(mes_path)
	var player: KakyuEventPlayer = EventPlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	player.open_content_set(source_root)
	var failures: Array[String] = []
	var reports: Array[String] = []
	for entry_name in CATALOGS:
		var expected: Dictionary = CATALOGS[entry_name]
		var setup_state_record_count := -1
		var setup_final_state_record_count := -1
		var reaches_event_choice := bool(expected.get("setup_reaches_event_choice", false))
		player.load_entry(entry_name)
		var document: Dictionary = player.get("_document")
		var catalog: Dictionary = player.get("_active_address_catalog")
		if (
			str(player.get("_selected_entry")) != entry_name
			or str(document.get("entry_sha256", "")) != str(expected.entry_sha256)
			or int(document.get("header", {}).get("entry_count", -1)) != int(expected.entry_count)
			or not catalog.get("ok", false)
			or int(catalog.get("fragment_count", -1)) != int(expected.fragment_count)
			or str(catalog.get("caller_entry", "")) != str(expected.caller_entry)
			or int(catalog.get("caller_offset", -1)) != int(expected.caller_offset)
			or int(catalog.get("caller_resume", -1)) != int(expected.caller_resume)
			or (
				expected.has("setup_start_coordinate")
				and (
					int(catalog.get("setup_start_coordinate", -1)) != int(expected.setup_start_coordinate)
					or int(catalog.get("setup_entry_offset", -1)) != int(expected.setup_entry_offset)
					or int(catalog.get("setup_entry_index", -1)) != int(expected.setup_entry_index)
					or str(catalog.get("setup_start_kind", "")) != str(expected.setup_start_kind)
					or str(catalog.get("exe_audit_schema", "")) != str(expected.exe_audit_schema)
					or int(catalog.get("setup_shared_routine", -1)) != int(expected.setup_shared_routine)
					or int(catalog.get("setup_shared_offset", -1)) != int(expected.setup_shared_offset)
					or int(catalog.get("setup_shared_resume", -1)) != int(expected.setup_shared_resume)
					or int(catalog.get("setup_native_offset", -1)) != int(expected.setup_native_offset)
					or int(catalog.get("setup_native_resume", -1)) != int(expected.setup_native_resume)
					or int(catalog.get("setup_native_record_count", -1)) != int(expected.setup_native_record_count)
					or catalog.get("setup_native_presentation_boundaries", []) != expected.get("setup_native_presentation_boundaries", [])
					or str(catalog.get("setup_extension_mmo", "")) != str(expected.get("setup_extension_mmo", ""))
					or catalog.get("setup_extension_terminals", []) != expected.get("setup_extension_terminals", [])
					or catalog.get("setup_definition_calls", []) != expected.get("setup_definition_calls", [])
					or catalog.get("route_definition_calls", []) != expected.get("route_definition_calls", [])
					or catalog.get("route_native_record_boundaries", []) != expected.get("route_native_record_boundaries", [])
					or catalog.get("route_script_dispatches", []) != expected.get("route_script_dispatches", [])
					or str(catalog.get("route_terminal_status", "")) != str(expected.get("route_terminal_status", ""))
					or int(catalog.get("route_terminal_offset", -1)) != int(expected.get("route_terminal_offset", -1))
					or int(catalog.get("route_choice_state_index", -1)) != int(expected.get("route_choice_state_index", -1))
					or catalog.get("route_choice_values", []) != expected.get("route_choice_values", [])
					or int(catalog.get("route_completion_state_index", -1)) != int(expected.get("route_completion_state_index", -1))
					or bool(catalog.get("setup_reaches_event_choice", false)) != reaches_event_choice
					or str(catalog.get("setup_terminal_status", "")) != str(expected.setup_terminal_status)
					or int(catalog.get("setup_terminal_offset", -1)) != int(expected.setup_terminal_offset)
					or int(catalog.get("setup_terminal_message_count", -1)) != int(expected.get("setup_terminal_message_count", -1))
					or catalog.get("setup_mmo_followup_write", {}) != expected.get("setup_mmo_followup_write", {})
					or (
						expected.has("setup_return")
						and int(catalog.get("setup_return", -1)) != int(expected.setup_return)
					)
					or (
						expected.has("nested_start_coordinate")
						and (
							int(catalog.get("nested_start_coordinate", -1)) != int(expected.nested_start_coordinate)
							or int(catalog.get("bootstrap_target", -1)) != int(expected.bootstrap_target)
							or int(catalog.get("bootstrap_entry_index", -1)) != int(expected.bootstrap_entry_index)
						)
					)
				)
			)
		):
			print("CATALOG_SETUP_DIAGNOSTIC status=%s offset=0x%X messages=%d path=%s" % [str(catalog.get("setup_terminal_status", "")), int(catalog.get("setup_terminal_offset", -1)), int(catalog.get("setup_terminal_message_count", -1)), JSON.stringify(catalog.get("setup_path", []))])
			failures.append("%s source/catalog contract changed: %s" % [entry_name, str(catalog)])
			continue
		failures.append_array(_rejected_source_contracts(player, entry_name, document))
		var start_button: Button = player.get("start_event_button")
		var preview_button: Button = player.get("preview_fragment_button")
		var status_text := str((player.get_node("Margin/Layout/StatusLabel") as Label).text)
		if (
			start_button.disabled != not reaches_event_choice
			or (reaches_event_choice and start_button.text != "Start Confirmed Event")
			or not preview_button.disabled
			or (
				str(expected.get("setup_start_kind", "")) == "audited_nested_call"
				and not reaches_event_choice
				and not status_text.contains("Catalog setup only")
			)
		):
			failures.append("%s initial catalog controls do not fail closed" % entry_name)
			continue
		var fragment_audit := _audit_all_fragments(document)
		if not fragment_audit.ok:
			failures.append("%s exhaustive fragment audit failed: %s" % [
				entry_name,
				str(fragment_audit.error),
			])
			continue
		var ui_summaries: Dictionary = player.get("_catalog_fragment_summaries")
		if ui_summaries.size() != int(expected.fragment_count):
			failures.append("%s UI first-stop summary count changed: %d" % [
				entry_name,
				ui_summaries.size(),
			])
			continue
		var address_tree: Tree = player.get("address_tree")
		var tree_root := address_tree.get_root()
		var expected_tree_rows := int(expected.entry_count) + 1 + (1 if reaches_event_choice else 0)
		if tree_root == null or tree_root.get_child_count() != expected_tree_rows:
			failures.append("%s address tree did not expose bootstrap plus every table entry" % entry_name)
			continue
		var setup_item: TreeItem = null
		var fragment_item: TreeItem = null
		for row_index in range(tree_root.get_child_count()):
			var candidate := tree_root.get_child(row_index)
			if str(candidate.get_metadata(1)) == "catalog_setup":
				setup_item = candidate
			elif str(candidate.get_metadata(1)) == "catalog_fragment" and int(candidate.get_metadata(2)) == 1:
				fragment_item = candidate
		if (
			setup_item == null
			or fragment_item == null
			or setup_item.get_text(0) != "Catalog setup #0000"
			or str(setup_item.get_metadata(1)) != "catalog_setup"
			or fragment_item.get_text(0) != "Fragment #0001"
			or str(fragment_item.get_metadata(1)) != "catalog_fragment"
			or int(fragment_item.get_metadata(2)) != 1
			or not fragment_item.get_text(2).contains("msg")
			or not fragment_item.get_tooltip_text(2).contains("native host selection is unresolved")
			or (
				str(expected.get("setup_start_kind", "")) == "audited_nested_call"
				and reaches_event_choice
				and not setup_item.get_tooltip_text(0).contains("zero-coordinate event bootstrap")
			)
			or (
				str(expected.get("setup_start_kind", "")) == "audited_nested_call"
				and not reaches_event_choice
				and not setup_item.get_tooltip_text(0).contains("zero-coordinate nested call")
			)
			or (
				str(expected.get("setup_start_kind", "")) == "source_table_entry"
				and not setup_item.get_tooltip_text(0).contains("host activation remains unresolved")
			)
		):
			failures.append(
				"%s address tree catalog labels changed: setup=%s/%s fragment=%s/%s/%s tooltip=%s"
				% [
					entry_name,
					setup_item.get_text(0) if setup_item != null else "missing",
					str(setup_item.get_metadata(1)) if setup_item != null else "missing",
					fragment_item.get_text(0) if fragment_item != null else "missing",
					fragment_item.get_text(2) if fragment_item != null else "missing",
					str(fragment_item.get_metadata(1)) if fragment_item != null else "missing",
					fragment_item.get_tooltip_text(2) if fragment_item != null else "missing",
				]
			)
			continue
		if expected.has("setup_start_coordinate"):
			player.set("_state", SandboxStateScript.new(1))
			setup_item.select(0)
			player.select_address()
			var expected_setup_action := "Start Confirmed Event" if reaches_event_choice else "Preview Setup"
			if preview_button.disabled or preview_button.text != expected_setup_action:
				failures.append("%s audited setup did not enable %s" % [entry_name, expected_setup_action])
				continue
			if reaches_event_choice:
				player.start_event()
			else:
				player._on_preview_catalog_fragment_pressed()
			var setup_result_status := str(player.get("_preview_result_status"))
			var setup_trace_root := (player.get("trace_tree") as Tree).get_root()
			var setup_first_offset := ""
			var setup_first_effect := ""
			if setup_trace_root != null and setup_trace_root.get_child_count() >= 1:
				setup_first_offset = setup_trace_root.get_child(0).get_text(1)
				setup_first_effect = setup_trace_root.get_child(0).get_text(3)
			var setup_state_records := (player.get("_state") as KakyuMesSandboxState).to_records()
			setup_state_record_count = setup_state_records.size()
			if (
				setup_result_status != "shared_routine_boundary"
				or setup_trace_root == null
				or setup_trace_root.get_child_count() < 1
				or not setup_first_effect.contains(str(expected.setup_first_effect))
				or setup_first_offset != "%s · 0x%08X" % [entry_name, int(expected.setup_start_coordinate)]
				or int(player.get("_preview_result_offset")) != int(expected.setup_shared_offset)
				or str(player.get("_preview_event_session")) != "catalog_setup"
				or int(player.get("_preview_catalog_fragment_index")) != 0
				or (
					reaches_event_choice
					and not str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("Started confirmed EVENTD14 zero-coordinate event bootstrap")
				)
				or (
					not reaches_event_choice
					and not str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("no event fragment selected")
				)
				or (
					str(expected.setup_start_kind) == "source_table_entry"
					and not str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("host activation unresolved")
				)
				or setup_state_record_count != int(expected.setup_state_change_count)
				or int(player.get("_continuation_offset")) != int(expected.setup_shared_resume)
				or int((player.get("_continuation_context") as Dictionary).get("routine_id", -1)) != int(expected.setup_shared_routine)
			):
				failures.append("%s catalog setup preview changed: status=%s first=%s/%s session=%s fragment=%d state_records=%d" % [
					entry_name,
					setup_result_status,
					setup_first_offset,
					setup_first_effect,
					str(player.get("_preview_event_session")),
					int(player.get("_preview_catalog_fragment_index")),
					setup_state_records.size(),
				])
				continue
			player.advance()
			var native_result_status := str(player.get("_preview_result_status"))
			var native_context: Dictionary = player.get("_continuation_context")
			var continue_button: Button = player.get("continue_button")
			if (
				native_result_status != "native_record_boundary"
				or int(player.get("_preview_result_offset")) != int(expected.setup_native_offset)
				or int(player.get("_continuation_offset")) != int(expected.setup_native_resume)
				or str(native_context.get("kind", "")) != "catalog_setup_native_records_omitted"
				or str(native_context.get("native_record_policy", "")) != "omit_bounded"
				or continue_button.disabled
				or continue_button.text != "Continue (Omit Setup Records)"
			):
				failures.append("%s catalog setup native boundary changed: status=%s offset=0x%X resume=0x%X context=%s" % [
					entry_name,
					native_result_status,
					int(player.get("_preview_result_offset")),
					int(player.get("_continuation_offset")),
					str(native_context),
				])
				continue
			var setup_continuations: Array[String] = [
				"routine%d@0x%X" % [
					int(expected.setup_shared_routine),
					int(expected.setup_shared_offset),
				],
				"record@0x%X->0x%X" % [
					int(expected.setup_native_offset),
					int(expected.setup_native_resume),
				],
			]
			player.advance()
			for _continuation_step in range(128):
				var continued_status := str(player.get("_preview_result_status"))
				if continued_status == "script_return":
					break
				var continued_context: Dictionary = player.get("_continuation_context")
				if continued_status == "shared_routine_boundary":
					if expected.has("setup_extension_terminal_offset") and (
						int(player.get("_preview_result_offset")) == int(expected.setup_extension_terminal_offset)
						and int(expected.setup_extension_terminal_routine) > 0
					):
						setup_continuations.append("routine%d@0x%X" % [
							int(expected.setup_extension_terminal_routine),
							int(player.get("_preview_result_offset")),
						])
						break
					if str(continued_context.get("kind", "")) != "shared_library":
						break
					setup_continuations.append("routine%d@0x%X" % [
						int(continued_context.get("routine_id", -1)),
						int(player.get("_preview_result_offset")),
					])
				elif continued_status in ["native_presentation_boundary", "native_record_boundary"]:
					if not str(continued_context.get("kind", "")).begins_with("catalog_setup_native_"):
						break
					setup_continuations.append("%s@0x%X->0x%X" % [
						"record" if continued_status == "native_record_boundary" else "presentation",
						int(player.get("_preview_result_offset")),
						int(player.get("_continuation_offset")),
					])
				elif continued_status == "definition_invoke_boundary":
					if str(continued_context.get("kind", "")) != "catalog_setup_registered_definition":
						break
					setup_continuations.append("def%d@0x%X->0x%X" % [
						int(continued_context.get("definition_id", -1)),
						int(player.get("_preview_result_offset")),
						int(player.get("_continuation_offset")),
					])
				elif continued_status == "library_definition_invoke_boundary":
					if str(continued_context.get("kind", "")) != "registered_def_library":
						break
					setup_continuations.append("library_def26@0x%X->0x%X" % [
						int(player.get("_preview_result_offset")),
						int(player.get("_continuation_offset")),
					])
				elif continued_status == "dialogue_boundary":
					if str(continued_context.get("kind", "")) != "dialogue":
						break
					setup_continuations.append("dialogue@0x%X" % int(player.get("_preview_result_offset")))
				elif continued_status == "def_selection_boundary":
					var definition_signatures: Array[String] = []
					for untyped_definition in player.get("_preview_definitions"):
						var choice_definition: Dictionary = untyped_definition
						definition_signatures.append("%d@0x%X->0x%X" % [
							int(choice_definition.get("definition_id", -1)),
							int(choice_definition.get("source_offset", -1)),
							int(choice_definition.get("target_offset", -1)),
						])
					setup_continuations.append("choice@0x%X:%s" % [
						int(player.get("_preview_result_offset")),
						",".join(definition_signatures),
					])
					break
				else:
					break
				if int(player.get("_continuation_offset")) < 0:
					break
				player.advance()
			var setup_end_message := str((player.get("_preview_message_label") as Label).text)
			var setup_end_footer := str((player.get("_preview_footer_label") as Label).text)
			setup_final_state_record_count = (player.get("_state") as KakyuMesSandboxState).to_records().size()
			var expected_final_status := str(expected.get("setup_extension_terminal_status", expected.setup_terminal_status))
			var expected_final_offset := int(expected.get("setup_extension_terminal_offset", expected.setup_terminal_offset))
			var terminal_ok: bool = (
				str(player.get("_preview_result_status")) == expected_final_status
				and int(player.get("_preview_result_offset")) == expected_final_offset
				and setup_continuations == expected.setup_expected_path
				and bool(player.get("_preview_catalog_setup_native_fx_omitted"))
				and not bool(player.get("_preview_event_complete"))
				and setup_final_state_record_count == int(expected.setup_final_state_change_count)
			)
			if reaches_event_choice:
				# EP-10 unit 5bc part 3: EVENTD14's per-event confirmed choice
				# activation was retired with the hand-authored playback code
				# that built it; the generic routine-40 remake bridge
				# (`_activate_routine40_result_bridge`, shared with every
				# other choice this structurally qualifies) reaches this same
				# def_selection_boundary and activates on its own.
				var choice_projection: Dictionary = player.get("_choice_projection")
				terminal_ok = (
					terminal_ok
					and str(player.get("_preview_event_session")) == "catalog_setup"
					and str(choice_projection.get("kind", "")) == "routine40_result_bridge"
					and int(choice_projection.get("anchor_offset", -1)) == 0x0865
					and int(choice_projection.get("resume_offset", -1)) == 0x0947
					and int(choice_projection.get("state_index", -1)) == 21
					and (player.get("_preview_definitions") as Array).size() == 3
					and setup_end_message.begins_with("> 1. ")
					and setup_end_footer.contains("Routine 40 remake bridge")
					and setup_end_footer.contains("option 1/3")
				)
			elif expected.has("setup_extension_terminal_offset"):
				var mmo_followup_write: Dictionary = expected.get("setup_mmo_followup_write", {})
				var setup_state: KakyuMesSandboxState = player.get("_state")
				terminal_ok = (
					terminal_ok
					and str(player.get("_preview_event_session")) == "catalog_setup"
					and str(player.get("_preview_mmo_name")).to_upper() == str(expected.setup_extension_mmo).to_upper()
					and int(player.get("_continuation_offset")) < 0
					and (player.get("continue_button") as Button).disabled
					and setup_end_message.contains("stopped safely before shared routine %d" % int(expected.setup_extension_terminal_routine))
					and setup_end_footer.contains("branch global_u8[4000]=1")
					and setup_end_footer.contains("no further continuation")
					and not mmo_followup_write.is_empty()
					and setup_state.read_value(
						"banked_u16",
						int(mmo_followup_write.index),
						int(mmo_followup_write.bank)
					) == int(mmo_followup_write.value)
				)
			elif str(expected.setup_terminal_status) == "script_return":
				terminal_ok = (
					terminal_ok
					and setup_end_message.contains("Catalog setup preview ended")
					and setup_end_message.contains("No event fragment was selected")
					and setup_end_footer.contains("native setup record effects omitted")
					and setup_end_footer.contains("sandbox changes remain isolated")
					and setup_end_message.contains("Host activation remains unresolved")
					and setup_end_footer.contains("source-table analysis")
				)
			else:
				var mmo_followup_write: Dictionary = expected.get("setup_mmo_followup_write", {})
				var setup_state: KakyuMesSandboxState = player.get("_state")
				terminal_ok = (
					terminal_ok
					and str(player.get("_preview_event_session")) == "catalog_setup"
					and (player.get("_preview_messages") as Array).size() == int(expected.setup_terminal_message_count)
					and setup_end_footer.contains("original CP932")
					and int(player.get("_continuation_offset")) < 0
					and not mmo_followup_write.is_empty()
					and setup_state.read_value(
						"banked_u16",
						int(mmo_followup_write.index),
						int(mmo_followup_write.bank)
					) == int(mmo_followup_write.value)
				)
			if not terminal_ok:
				print("CATALOG_COMPLETION_DIAGNOSTIC status=%s offset=0x%X messages=%d" % [str(player.get("_preview_result_status")), int(player.get("_preview_result_offset")), (player.get("_preview_messages") as Array).size()])
				failures.append("%s catalog setup completion changed: status=%s offset=0x%X path=%s message=%s footer=%s state_records=%d" % [
					entry_name,
					str(player.get("_preview_result_status")),
					int(player.get("_preview_result_offset")),
					str(setup_continuations),
					setup_end_message,
					setup_end_footer,
					(player.get("_state") as KakyuMesSandboxState).to_records().size(),
				])
				continue
			player.set("_state", SandboxStateScript.new(1))
			player.load_entry(entry_name)
			address_tree = player.get("address_tree")
			tree_root = address_tree.get_root()
			fragment_item = null
			if tree_root != null:
				for row_index in range(tree_root.get_child_count()):
					var candidate := tree_root.get_child(row_index)
					if str(candidate.get_metadata(1)) == "catalog_fragment" and int(candidate.get_metadata(2)) == 1:
						fragment_item = candidate
						break
			if fragment_item == null:
				failures.append("%s fragment 1 disappeared after caller-route validation" % entry_name)
				continue
		fragment_item.select(0)
		player.select_address()
		if preview_button.disabled or preview_button.text != "Preview #0001":
			failures.append("%s fragment 1 did not enable the dedicated preview action" % entry_name)
			continue
		player._on_preview_catalog_fragment_pressed()
		var messages: Array = player.get("_preview_messages")
		var result_status := str(player.get("_preview_result_status"))
		var trace_tree: Tree = player.get("trace_tree")
		var trace_root := trace_tree.get_root()
		if (
			result_status != "dialogue_boundary"
			or messages.is_empty()
			or trace_root == null
			or trace_root.get_child_count() < 2
			or not str((player.get("_preview_entry_label") as Label).text).contains("fragment #0001")
			or not str((player.get_node("Margin/Layout/StatusLabel") as Label).text).contains("host selection order unresolved")
			or not (player.get("_state") as KakyuMesSandboxState).to_records().is_empty()
		):
			failures.append("%s fragment 1 preview changed: status=%s messages=%d" % [
				entry_name,
				result_status,
				messages.size(),
			])
			continue
		var setup_state_report := "n/a" if setup_state_record_count < 0 else str(setup_state_record_count)
		var setup_final_state_report := "n/a" if setup_final_state_record_count < 0 else str(setup_final_state_record_count)
		reports.append("%s fragments=%d statuses=%s reached_messages=%d stateful=%d setup_state_changes=%s/%s preview_status=%s messages=%d" % [
			entry_name,
			int(expected.fragment_count),
			_format_counts(fragment_audit.status_counts),
			int(fragment_audit.reached_message_count),
			int(fragment_audit.stateful_fragment_count),
			setup_state_report,
			setup_final_state_report,
			result_status,
			messages.size(),
		])
	if FileAccess.get_sha256(mes_path) != source_sha:
		failures.append("source mes.arc changed during read-only catalog validation")
	player.queue_free()
	await process_frame
	if not failures.is_empty():
		_fail("Event Player catalog integration failed: %s; reports=%s" % [
			"; ".join(failures),
			", ".join(reports),
		])
		return
	print(
		"PASS: Event Player original fragment catalogs and EVENTD14 caller BGM/handoff; %s; original mes.arc unchanged"
		% ", ".join(reports)
	)
	quit(0)


func _audit_all_fragments(document: Dictionary) -> Dictionary:
	var entries: Array = document.get("entries", [])
	var table_offsets: Array[int] = []
	for untyped_offset in document.get("header", {}).get("entry_offsets", []):
		table_offsets.append(int(untyped_offset))
	var status_counts := {}
	var reached_message_count := 0
	var stateful_fragment_count := 0
	for entry_index in range(1, entries.size()):
		var entry: Dictionary = entries[entry_index]
		var state := SandboxStateScript.new(1)
		var result := MesEventRunnerScript.new().run(
			document.bytecode,
			int(entry.get("offset", -1)),
			state,
			int(document.get("header", {}).get("code_size", -1)),
			MesEventRunnerScript.DEFAULT_MAX_STEPS,
			{"address_table_offsets": table_offsets}
		)
		var status := str(result.get("status", "missing_status"))
		status_counts[status] = int(status_counts.get(status, 0)) + 1
		reached_message_count += (result.get("messages", []) as Array).size()
		if not (result.get("state_diff", []) as Array).is_empty():
			stateful_fragment_count += 1
		if INVALID_FRAGMENT_STATUSES.has(status):
			return {
				"ok": false,
				"error": "fragment #%04d stopped with %s at 0x%X" % [
					entry_index,
					status,
					int(result.get("offset", -1)),
				],
			}
	return {
		"ok": true,
		"status_counts": status_counts,
		"reached_message_count": reached_message_count,
		"stateful_fragment_count": stateful_fragment_count,
	}


func _rejected_source_contracts(
	player: KakyuEventPlayer, entry_name: String, document: Dictionary
) -> Array[String]:
	# The contract above proves the guard accepts the original. On its own that
	# cannot show the guard would refuse anything, and this catalog path is the
	# one EVENTD06 and EVENTD14 rely on instead of a per-event start validator.
	# Each case below is rejected for a different reason inside
	# `_validate_address_catalog_source`, so a guard that lost one still fails.
	var failures: Array[String] = []
	var definition: Dictionary = player.confirmed_address_catalog(
		entry_name, str(document.get("entry_sha256", ""))
	)
	if definition.is_empty():
		return ["%s has no confirmed address catalog to test rejection against" % entry_name]
	var changed_hash: Dictionary = document.duplicate(true)
	changed_hash["entry_sha256"] = "00"
	player.set("_document", changed_hash)
	if bool(player.catalog_source_contract_evidence(definition).get("ok", false)):
		failures.append("%s catalog source contract accepted a changed entry hash" % entry_name)

	var changed_count: Dictionary = document.duplicate(true)
	var header: Dictionary = changed_count.get("header", {})
	header["entry_count"] = int(header.get("entry_count", 0)) + 1
	changed_count["header"] = header
	player.set("_document", changed_count)
	if bool(player.catalog_source_contract_evidence(definition).get("ok", false)):
		failures.append("%s catalog source contract accepted a changed address-table count" % entry_name)

	# Restore the loaded document itself, not a copy of it, so the player and
	# this validator keep sharing one object exactly as they did on entry.
	player.set("_document", document)
	var changed_caller: Dictionary = definition.duplicate(true)
	changed_caller["caller_sha256"] = "00"
	if bool(player.catalog_source_contract_evidence(changed_caller).get("ok", false)):
		failures.append("%s catalog source contract accepted a changed caller hash" % entry_name)

	var changed_definition_hash: Dictionary = definition.duplicate(true)
	changed_definition_hash["entry_sha256"] = "00"
	if bool(player.catalog_source_contract_evidence(changed_definition_hash).get("ok", false)):
		failures.append("%s catalog source contract accepted a changed declared entry hash" % entry_name)

	if not bool(player.catalog_source_contract_evidence(definition).get("ok", false)):
		failures.append("%s catalog source contract stopped accepting the restored original" % entry_name)
	return failures


func _format_counts(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s:%d" % [str(key), int(counts[key])])
	return ",".join(parts)


