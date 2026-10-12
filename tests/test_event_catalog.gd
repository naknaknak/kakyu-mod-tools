extends "res://tests/test_case.gd"

const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"


func _ready() -> void:
	var catalog := EventCatalogScript.new()
	var loaded: Dictionary = catalog.load_file(CATALOG_PATH)
	_check(loaded.get("ok", false), "seeded Event Catalog loads through Content Core")
	if not loaded.get("ok", false):
		push_error(str(loaded.get("error", "Catalog validation failed.")))
		get_tree().quit(1)
		return
	_check(loaded.get("schema", "") == "kakyu_event_player_catalog/v8", "seeded catalog exposes the versioned schema")
	_check(int(loaded.get("catalog_revision", -1)) == 43, "seeded catalog records revision 43 (TD-56 C5: each row's `resources` gains the restored `LIBLARY.LIB` items, 17,020 -> 18,113 items in 293 rows; revision 42, TD-56 C4 bridge: the 13 analysis-group profiles C3 re-derived are rebound in the 14 rows that name them, rows otherwise as 41; revision 41, WD-21 U2 C5: each row's `resources` is its event definition's measured media list, 17,020 items; revision 40, EP-12 TALK follow-ups: `N_TALK1`'s resume measured to reach the `FLOOR5.MES` handoff, its row three hops; revision 39, EP-12 TALK rest unit: the other eleven heroines' conversation scripts, Tina's and the characters'; revision 38, EP-12 TALK K unit: heroine K's nine; revision 37, EP-12 H unit: the 13 recollection ladders of the room)")
	_check(int(loaded.get("event_count", -1)) == 681, "seeded catalog contains 681 generated records (EP-10 + EP-12's a..l-date flow rows + the 365 album scenes of the 13 menus + the 13 recollection ladders + the 114 conversation scripts of the twelve heroines, Tina and the characters N..Q)")
	_check(loaded.get("classification_counts", {}).get("playable_event", 0) == 648 and loaded.get("classification_counts", {}).get("duplicate_route", 0) == 33, "seeded catalog classifies 648 rows as playable and 33 album scenes as duplicate_route (EP-12 TALK rest unit: +105 playable conversation scripts; EP-12 TALK K unit: +9 playable conversation scripts; EP-12 SCENE all-menus unit: 29 EVENT twins and the 4 K copies of H scenes; EP-12 H unit: +13 playable ladders; EP-03 step 2 closed the last 3 dependency stops as chain)")
	_check(loaded.get("classification_counts", {}).get("unresolved_route", 0) == 0, "seeded catalog classifies 0 rows as unresolved routes")
	_check(loaded.get("playback_status_counts", {}).get("minimal_playback", 0) == 681, "seeded catalog carries 681 minimal-playback rows")
	_check(loaded.get("playback_status_counts", {}).get("analysis_only", 0) == 0, "seeded catalog carries 0 analysis-only rows")
	_check(int(loaded.get("generated_count", -1)) == 681, "seeded catalog pins every one of its 681 rows as generated")

	var source_document := _read_catalog_document()
	_check(not source_document.is_empty(), "seeded catalog is parseable JSON")
	_check(not _contains_machine_or_payload_field(source_document), "seeded catalog contains no machine path, dialogue, payload, or bytecode field")

	_test_accessors(catalog)
	_test_browser(catalog)
	_test_plain_group_route(catalog)
	_test_choice_group_route(catalog)
	_test_analysis_only_group_route(catalog)
	_test_tool_preset(catalog)
	_test_terminal_contract(catalog, source_document)
	_test_by_name_lookups(catalog, source_document)
	_test_validation_failures(source_document)
	_test_resources(source_document)
	_test_vocabulary()
	_test_slug_rule()

	get_tree().quit(1 if _failed else 0)


func _test_accessors(catalog: KakyuEventCatalog) -> void:
	var detached := catalog.get_events()
	detached[0].display.title = "mutated"
	_check(str(catalog.get_events()[0].display.title) != "mutated", "catalog get_events returns detached copies")
	_check(not catalog.get_event("original/eventa01/27c3b-00000697").is_empty(), "catalog get_event resolves a generated row by id")
	var first_id := str(catalog.get_events()[0].event_id)
	var original_title := str(catalog.get_event(first_id).display.title)
	_check(catalog.get_event(first_id).display.title == original_title, "catalog accessors return deep copies")
	_check(catalog.get_event("original/missing").is_empty(), "an unknown event id resolves to no event")


func _test_browser(catalog: KakyuEventCatalog) -> void:
	var browser: Dictionary = catalog.build_browser_rows()
	_check(browser.ok and browser.schema == "kakyu_event_catalog_browser/v1" and browser.visible_count == 681, "catalog builds a versioned path-free browser projection")
	var mahoko := catalog.build_browser_rows({"character_id": "MAHOKO"})
	_check(mahoko.ok and mahoko.visible_count == 44, "catalog browser filters character IDs without case sensitivity (9 events + her 26 album scenes + her recollection ladder + her 8 conversation scripts)")
	var blocked := catalog.build_browser_rows({"playback_status": "blocked", "blocking_only": true})
	_check(blocked.ok and blocked.visible_count == 0, "catalog browser reports no seeded hard-blocked playback route")
	var type_rows := catalog.build_browser_rows({"event_type": "character_event", "text": "maki"})
	_check(type_rows.ok and type_rows.visible_count == 9, "catalog browser combines event-type and free-text filters (EP-12 PROMIS checkpoint C: +1, maki's own new 01m-d-promis row - an ordinary, non-flow analysis-group site, so unlike a flow row its own categories include \"character_event\"; EP-12 H unit: +1, her recollection ladder, an ordinary site row tagged character_event)")
	var analysis_only_rows := catalog.build_browser_rows({"playback_status": "analysis_only"})
	_check(analysis_only_rows.ok and analysis_only_rows.visible_count == 0, "catalog browser's analysis-only filter matches 0 rows (EP-03 step 2 closed the last 3 dependency stops as chain)")
	var minimal_rows := catalog.build_browser_rows({"playback_status": "minimal_playback"})
	_check(minimal_rows.ok and minimal_rows.visible_count == 681, "catalog browser's minimal-playback filter matches all 681 generated minimal-playback rows")
	var b01_browser_row: Dictionary = {}
	for row in browser.rows:
		if str(row.event_id) == "original/eventb01/13c-00000f93":
			b01_browser_row = row
			break
	_check(b01_browser_row.has("compatibility") and b01_browser_row.has("recommended_preset") and b01_browser_row.has("blockers"), "catalog browser exposes compatibility, recommended preset, and blocker summaries")
	_check(b01_browser_row.recommended_preset.preset_id == "13c-b01-baseline" and b01_browser_row.preset_count == 7, "a promoted row's browser entry names its first original-branch preset and full preset count")
	var detached_rows: Array = browser.rows
	var original_first_row_title: String = str(detached_rows[0].title)
	detached_rows[0].title = "changed"
	_check(catalog.build_browser_rows().rows[0].title == original_first_row_title, "catalog browser projections cannot mutate the loaded catalog")
	_check(not catalog.build_browser_rows({"playback_status": "future"}).ok and not catalog.build_browser_rows({"unknown": true}).ok, "catalog browser rejects invalid and unknown filters")


func _test_plain_group_route(catalog: KakyuEventCatalog) -> void:
	var plain_row_id := "original/eventg01/30c-00000e52"
	var plain_row := catalog.get_event(plain_row_id)
	_check(not plain_row.is_empty() and plain_row.has("analysis_group") and plain_row.choices.is_empty(), "the fixture plain row is a generated row with no catalog choices")
	var plain_request := catalog.build_play_request(plain_row_id, "")
	_check(plain_request.get("ok", false) and str(plain_request.execution_model) == "group_route" and plain_request.selection == {}, "build_play_request on a plain generated row returns group_route with an empty selection")
	_check(not catalog.build_play_request(plain_row_id, "missing-preset").get("ok", false) and not catalog.build_play_request("original/missing").get("ok", false), "catalog play requests fail closed on unknown preset and event ids")
	var no_group_document: Dictionary = _read_catalog_document()
	no_group_document.events[0].erase("analysis_group")
	var no_group_catalog := EventCatalogScript.new()
	_check(no_group_catalog.validate(no_group_document).get("ok", false), "a document with one row's analysis_group removed still validates (no other invariant depends on it)")
	var no_group_request := no_group_catalog.build_play_request(str(no_group_document.events[0].event_id))
	_check(
		not no_group_request.get("ok", false)
		and str(no_group_request.get("error", "")) == "Catalog entry has no analysis group; every playable row is generated from one.",
		"build_play_request refuses a row with no analysis_group with the dedicated message",
	)


func _test_choice_group_route(catalog: KakyuEventCatalog) -> void:
	var choice_row_id := "original/eventa01/27c3b-00000697"
	var choice_row := catalog.get_event(choice_row_id)
	_check(not choice_row.is_empty() and choice_row.has("analysis_group") and not choice_row.choices.is_empty(), "the fixture choice row is a generated row")
	var choice_request := catalog.build_play_request(choice_row_id, "")
	_check(
		choice_request.get("ok", false)
		and str(choice_request.execution_model) == "group_route"
		and choice_request.has("analysis_group") and choice_request.has("choices") and choice_request.has("terminals")
		and str(choice_request.selection.get("option_id", "")) == str(choice_row.choices[0].options[0].option_id),
		"build_play_request on a choice row returns group_route with the first measured option selected by default",
	)
	var multi_option_row_id := "original/eventj19/07m-00004190"
	var multi_option_row := catalog.get_event(multi_option_row_id)
	var second_option := str(multi_option_row.choices[0].options[1].option_id)
	var explicit_request := catalog.build_play_request(multi_option_row_id, "", second_option)
	_check(explicit_request.get("ok", false) and str(explicit_request.selection.option_id) == second_option, "build_play_request selects the requested option")
	_check(not catalog.build_play_request(choice_row_id, "", "not-an-option").get("ok", false), "an unknown option id is refused")
	var unmeasured_row_id := "original/eventa22/44m-0000c7f9"
	var unmeasured_row := catalog.get_event(unmeasured_row_id)
	_check(
		(unmeasured_row.choices[0].options[1].terminal_ids as Array).is_empty()
		and not catalog.build_play_request(unmeasured_row_id, "", "option-2").get("ok", false),
		"an unmeasured choice option is refused",
	)


func _test_analysis_only_group_route(catalog: KakyuEventCatalog) -> void:
	# EP-03 step 2 (owner ruling 2026-09-23): this fixture row's dependency
	# stop lands exactly on EVENTK01.MES's own intro dispatch, so it is now a
	# `chain` ending - promoted to playable_event/minimal_playback - and its
	# terminal carries that ruling's next_target rather than staying
	# unresolved_route/analysis_only.
	var chained_id := "original/eventh01/ground-00000a34"
	var chained_row := catalog.get_event(chained_id)
	_check(
		not chained_row.is_empty()
		and chained_row.classification == "playable_event"
		and chained_row.playback_status == "minimal_playback",
		"the fixture row is classified as a playable, minimal-playback route (EP-03 step 2 chain)",
	)
	var chain_terminal := {}
	for terminal in chained_row.get("terminals", []):
		if str(terminal.get("kind", "")) == "analysis_boundary" and str(terminal.get("runtime_status", "")) == "script_dispatch_boundary":
			chain_terminal = terminal
			break
	_check(not chain_terminal.is_empty() and str(chain_terminal.get("next_target", "")) == "EVENTK01.MES", "the fixture row's dependency-stop terminal carries the chained next_target")
	var request := catalog.build_play_request(chained_id)
	_check(request.get("ok", false) and str(request.execution_model) == "group_route", "a chained row still builds a group_route play request")


func _test_tool_preset(catalog: KakyuEventCatalog) -> void:
	var plain_row_id := "original/eventg01/30c-00000e52"
	var writes := [{"storage": "state_u16", "bank": 0, "index": 1, "value": 15}]
	var accepted := catalog.build_play_request(plain_row_id, "30c-g01a-clock-1500", "", {"kind": "tool_seeded_analysis", "writes": writes})
	_check(accepted.get("ok", false) and accepted.preset.kind == "tool_seeded_analysis" and accepted.preset.base_preset_id == "30c-g01a-clock-1500", "a group_route request accepts a tool-seeded starting state and names the catalog preset it started from")
	var wrong_kind := catalog.build_play_request(plain_row_id, "", "", {"kind": "original_branch", "writes": writes})
	_check(not wrong_kind.get("ok", false), "a tool-seeded starting state with a non-tool_seeded_analysis kind is refused")
	var overflowing_writes := [{"storage": "state_u16", "bank": 0, "index": 1, "value": 0x10000}]
	var overflowing := catalog.build_play_request(plain_row_id, "", "", {"kind": "tool_seeded_analysis", "writes": overflowing_writes})
	_check(not overflowing.get("ok", false), "an overflowing tool-seeded write is refused, never masked")


func _test_terminal_contract(catalog: KakyuEventCatalog, source_document: Dictionary) -> void:
	var event_id := "original/eventg01/30c-00000e52"
	var handoff := catalog.match_terminal(event_id, {
		"owner_entry": "EVENTG01.MES", "runtime_status": "script_handoff_boundary", "offset": 8042, "next_target": "FLOOR2.MES",
	})
	_check(handoff.get("ok", false) and handoff.outcome == "normal_completion" and handoff.route_ended, "match_terminal matches a generated row's own cataloged handoff")
	_check(
		not catalog.match_terminal(event_id, {"owner_entry": "30C.MES", "runtime_status": "script_handoff_boundary", "offset": 8042, "next_target": "FLOOR2.MES"}).ok,
		"match_terminal rejects the same offset attributed to the wrong owner entry",
	)
	_check(
		not catalog.match_terminal(event_id, {"owner_entry": "EVENTG01.MES", "runtime_status": "script_handoff_boundary", "offset": 8042, "next_target": "OTHER.MES"}).ok,
		"match_terminal rejects an outer-target drift at a cataloged coordinate",
	)
	var contract := catalog.build_terminal_contract(event_id)
	var detached_contract: Dictionary = contract.duplicate(true)
	detached_contract.stages[0].offset = 0
	_check(
		not catalog.match_terminal_contract(detached_contract, {"owner_entry": "EVENTG01.MES", "runtime_status": "script_handoff_boundary", "offset": 8042, "next_target": "FLOOR2.MES"}).ok
		and catalog.match_terminal(event_id, {"owner_entry": "EVENTG01.MES", "runtime_status": "script_handoff_boundary", "offset": 8042, "next_target": "FLOOR2.MES"}).ok,
		"a changed terminal-contract copy cannot mutate or bypass the loaded catalog contract",
	)


func _test_by_name_lookups(catalog: KakyuEventCatalog, source_document: Dictionary) -> void:
	var callee_owners := {}
	for event in source_document.events:
		var key := str(event.source.callee.entry).to_upper()
		callee_owners[key] = int(callee_owners.get(key, 0)) + 1
	var shared_entry := ""
	var unique_entry := ""
	for entry in callee_owners:
		if int(callee_owners[entry]) > 1 and shared_entry.is_empty():
			shared_entry = entry
		if int(callee_owners[entry]) == 1 and unique_entry.is_empty():
			unique_entry = entry
	_check(not shared_entry.is_empty() and not unique_entry.is_empty(), "the seeded catalog has both a shared and a unique callee entry to test")
	_check(catalog.find_callee_source(shared_entry).is_empty(), "a callee entry shared by two generated rows resolves to no callee source by name")
	_check(catalog.find_caller_source(shared_entry).is_empty(), "a callee entry shared by two generated rows resolves to no caller source by name")
	_check(not catalog.find_callee_source(unique_entry).is_empty(), "a unique callee entry resolves a callee source by name")
	_check(not catalog.find_caller_source(unique_entry).is_empty(), "a unique callee entry resolves a caller source by name")
	_check(
		catalog.find_callee_source(unique_entry) == catalog.find_callee_source(unique_entry.to_lower()),
		"a by-name callee lookup is case-insensitive",
	)
	_check(catalog.find_callee_source("").is_empty() and catalog.find_caller_source("").is_empty(), "an empty entry name resolves to no source")
	_check(EventCatalogScript.new().find_callee_source(unique_entry).is_empty(), "an unloaded catalog answers no callee source rather than a stale one")


## WD-21 U2 C5: every seeded row lists the media its measured route reaches as
## the v8 resource item (`resource_id` `res-<ordinal>`, `request_entry`,
## `request_offset`, `entry`; no `kind`, no hash, no branch), and the loader that
## already validated them refuses an item that breaks its rules.
func _test_resources(source_document: Dictionary) -> void:
	var total := 0
	var empty_rows := 0
	var shape_ok := true
	var ids_ok := true
	var ordinals_ok := true
	for event in source_document.events:
		var resources: Array = event.resources
		total += resources.size()
		if resources.is_empty():
			empty_rows += 1
		var seen := {}
		var ordinal := 1
		for item_value in resources:
			var item: Dictionary = item_value
			shape_ok = shape_ok and item.keys() == ["resource_id", "request_entry", "request_offset", "entry"]
			ids_ok = ids_ok and EventCatalogScript.is_slug(str(item.resource_id)) and not seen.has(item.resource_id)
			ordinals_ok = ordinals_ok and str(item.resource_id) == "res-%04d" % ordinal
			seen[item.resource_id] = true
			ordinal += 1
	_check(total == 18113, "the seeded rows list 18,113 resource items in all (TD-56 C5: 17,020 plus the 1,093 LIBLARY.LIB items)")
	_check(empty_rows == 0, "no seeded row has an empty resource list (every measured route reaches media)")
	_check(shape_ok, "every resource item has exactly resource_id, request_entry, request_offset and entry")
	_check(ids_ok, "every resource id is a slug, unique within its row")
	_check(ordinals_ok, "every row's resource ids are res-0001... in list order")

	# The mutation cases need a row with at least two resources (the duplicate-id case needs a pair), not a
	# fixed first row: a legitimately empty first row must fail one clear check, not error on `resources[0]`.
	var row := -1
	for index in range(source_document.events.size()):
		if (source_document.events[index].resources as Array).size() >= 2:
			row = index
			break
	_check(row >= 0, "a seeded row has at least two resources to mutate")
	if row < 0:
		return

	var unsafe_entry: Dictionary = source_document.duplicate(true)
	unsafe_entry.events[row].resources[0].entry = "A/B.MMO"
	_check(not EventCatalogScript.new().validate(unsafe_entry).get("ok", false), "a resource entry that is not a safe leaf fails closed")
	var unsafe_request: Dictionary = source_document.duplicate(true)
	unsafe_request.events[row].resources[0].request_entry = "..\\01M.MES"
	_check(not EventCatalogScript.new().validate(unsafe_request).get("ok", false), "a resource request entry that is not a safe leaf fails closed")
	var negative_offset: Dictionary = source_document.duplicate(true)
	negative_offset.events[row].resources[0].request_offset = -1
	_check(not EventCatalogScript.new().validate(negative_offset).get("ok", false), "a negative resource request offset fails closed")
	var duplicate_id: Dictionary = source_document.duplicate(true)
	var duplicated_resources: Array = duplicate_id.events[row].resources
	duplicated_resources[1].resource_id = duplicated_resources[0].resource_id
	_check(not EventCatalogScript.new().validate(duplicate_id).get("ok", false), "a duplicate resource id fails closed")
	var dangling_branch: Dictionary = source_document.duplicate(true)
	dangling_branch.events[row].resources[0]["branch_ids"] = ["no-such-branch"]
	_check(not EventCatalogScript.new().validate(dangling_branch).get("ok", false), "a resource naming an unknown branch fails closed")


func _test_validation_failures(source_document: Dictionary) -> void:
	var duplicate: Dictionary = source_document.duplicate(true)
	duplicate.events.append(duplicate.events[0].duplicate(true))
	_check(not EventCatalogScript.new().validate(duplicate).get("ok", false), "duplicate event ids fail closed")

	var unsafe_ref: Dictionary = source_document.duplicate(true)
	unsafe_ref.events[0].activation.document_refs = ["C:/local/source.txt"]
	_check(not EventCatalogScript.new().validate(unsafe_ref).get("ok", false), "machine-specific document references fail closed")

	var first_generated: Dictionary = source_document.events[0]
	_check(first_generated.has("analysis_group"), "every seeded row carries an analysis_group block")
	var malformed_group: Dictionary = source_document.duplicate(true)
	malformed_group.events[0].analysis_group.groups[0].erase("profile_sha256")
	_check(not EventCatalogScript.new().validate(malformed_group).get("ok", false), "a malformed analysis_group block fails closed")

	var invalid_classification: Dictionary = source_document.duplicate(true)
	invalid_classification.events[0].classification = "not_a_classification"
	_check(not EventCatalogScript.new().validate(invalid_classification).get("ok", false), "an invalid classification fails closed")

	var invalid_status: Dictionary = source_document.duplicate(true)
	invalid_status.events[0].playback_status = "complete_playback"
	_check(not EventCatalogScript.new().validate(invalid_status).get("ok", false), "an invalid playback status fails closed")

	var retired_analysis_route: Dictionary = source_document.duplicate(true)
	retired_analysis_route.events[0]["analysis_route"] = {}
	_check(not EventCatalogScript.new().validate(retired_analysis_route).get("ok", false), "a row carrying the retired analysis_route shape fails closed")

	var retired_caller_route: Dictionary = source_document.duplicate(true)
	retired_caller_route.events[0]["caller_route"] = {}
	_check(not EventCatalogScript.new().validate(retired_caller_route).get("ok", false), "a row carrying the retired caller_route shape fails closed")

	var minimal_index := -1
	for index in range(source_document.events.size()):
		if str(source_document.events[index].get("playback_status", "")) == "minimal_playback":
			minimal_index = index
			break
	_check(minimal_index >= 0, "at least one seeded row carries minimal_playback")
	if minimal_index >= 0:
		var minimal_blocking: Dictionary = source_document.duplicate(true)
		minimal_blocking.events[minimal_index].blockers.append({
			"blocker_id": "test-blocker",
			"class": "unsupported_opcode",
			"offset": 0,
			"blocks_playback": true,
			"document_refs": [],
		})
		_check(not EventCatalogScript.new().validate(minimal_blocking).get("ok", false), "a minimal_playback row mutated to a blocking blocker fails closed")

		var minimal_unresolved_choice: Dictionary = source_document.duplicate(true)
		var choices: Array = minimal_unresolved_choice.events[minimal_index].choices
		if not choices.is_empty():
			choices[0].result_interface = "unresolved"
			_check(not EventCatalogScript.new().validate(minimal_unresolved_choice).get("ok", false), "a minimal_playback row mutated to an unresolved choice fails closed")

	var invalid_terminal_kind: Dictionary = source_document.duplicate(true)
	invalid_terminal_kind.events[0].terminals[0].kind = "not_a_terminal_kind"
	_check(not EventCatalogScript.new().validate(invalid_terminal_kind).get("ok", false), "an invalid terminal kind fails closed")

	var invalid_kind_outcome: Dictionary = source_document.duplicate(true)
	invalid_kind_outcome.events[0].terminals[0].outcome = "rejected"
	_check(not EventCatalogScript.new().validate(invalid_kind_outcome).get("ok", false), "a terminal kind and outcome combination that is not in the vocabulary fails closed")

	var dangling_terminal: Dictionary = source_document.duplicate(true)
	var choice_index := -1
	for index in range(dangling_terminal.events.size()):
		if not (dangling_terminal.events[index].choices as Array).is_empty():
			choice_index = index
			break
	_check(choice_index >= 0, "at least one seeded row has a choice to mutate")
	if choice_index >= 0:
		dangling_terminal.events[choice_index].choices[0].options[0].terminal_ids = ["missing-terminal"]
		_check(not EventCatalogScript.new().validate(dangling_terminal).get("ok", false), "a dangling choice terminal reference fails closed")

	var payload_field: Dictionary = source_document.duplicate(true)
	payload_field.events[0]["payload_bytes"] = [1, 2, 3]
	_check(not EventCatalogScript.new().validate(payload_field).get("ok", false), "embedded payload fields fail closed")

	var unsorted: Dictionary = source_document.duplicate(true)
	var first = unsorted.events[0]
	unsorted.events[0] = unsorted.events[1]
	unsorted.events[1] = first
	_check(not EventCatalogScript.new().validate(unsorted).get("ok", false), "nondeterministic event ordering fails closed")

	# EP-03 step 2 (owner ruling 2026-09-23): a script_dispatch_boundary
	# terminal's next_target must name the callee entry of a row whose
	# source.caller matches the terminal's own owner_entry/offset.
	var chain_event_index := -1
	var chain_terminal_index := -1
	for index in range(source_document.events.size()):
		var event: Dictionary = source_document.events[index]
		var terminals: Array = event.get("terminals", [])
		for terminal_index in range(terminals.size()):
			var terminal: Dictionary = terminals[terminal_index]
			if str(terminal.get("kind", "")) == "analysis_boundary" and str(terminal.get("runtime_status", "")) == "script_dispatch_boundary" and not str(terminal.get("next_target", "")).is_empty():
				chain_event_index = index
				chain_terminal_index = terminal_index
				break
		if chain_event_index >= 0:
			break
	_check(chain_event_index >= 0, "at least one seeded row carries a script_dispatch_boundary terminal with a next_target")
	if chain_event_index >= 0:
		_check(EventCatalogScript.new().validate(source_document.duplicate(true)).get("ok", false), "the seeded catalog's script_dispatch_boundary next_target matches another row's intro dispatch (positive case)")

		var wrong_offset: Dictionary = source_document.duplicate(true)
		wrong_offset.events[chain_event_index].terminals[chain_terminal_index].offset = int(wrong_offset.events[chain_event_index].terminals[chain_terminal_index].offset) + 1
		_check(not EventCatalogScript.new().validate(wrong_offset).get("ok", false), "a script_dispatch_boundary next_target whose offset no longer matches any row's intro dispatch fails closed")

		var wrong_target: Dictionary = source_document.duplicate(true)
		wrong_target.events[chain_event_index].terminals[chain_terminal_index].next_target = "NOT_A_REAL_INTRO.MES"
		_check(not EventCatalogScript.new().validate(wrong_target).get("ok", false), "a script_dispatch_boundary next_target that does not name the matched row's callee entry fails closed")


func _test_vocabulary() -> void:
	_check(
		EventCatalogScript.PLAYBACK_STATUSES.has("minimal_playback")
		and EventCatalogScript.PLAYBACK_STATUSES.has("analysis_only")
		and EventCatalogScript.PLAYBACK_STATUSES.has("blocked")
		and EventCatalogScript.PLAYBACK_STATUSES.has("not_applicable")
		and not EventCatalogScript.PLAYBACK_STATUSES.has("complete_playback")
		and not EventCatalogScript.PLAYBACK_STATUSES.has("partial_playback"),
		"the catalog's playback-status vocabulary is exactly the EP-10 unit 5b/c set",
	)
	_check(
		EventCatalogScript.CLASSIFICATIONS.has("playable_event")
		and EventCatalogScript.CLASSIFICATIONS.has("unresolved_route"),
		"the catalog's classification vocabulary still names playable_event and unresolved_route",
	)


# The public slug rule is the one the catalog's own validation applies and the
# playback package's catalog binding calls, so both agree by construction.
func _test_slug_rule() -> void:
	for accepted in ["kakyu-original-events", "a", "a_b-9", "0"]:
		_check(EventCatalogScript.is_slug(accepted), "is_slug accepts %s" % accepted)
	for refused in ["", "Upper", "a b", "a/b", "a.b", "a\n", "é", "a:b"]:
		_check(not EventCatalogScript.is_slug(refused), "is_slug refuses %s" % JSON.stringify(refused))
	var document := _read_catalog_document()
	document.catalog_id = "Not-A-Slug"
	_check(not EventCatalogScript.new().validate(document).get("ok", false), "the catalog's own validation refuses an id that is_slug refuses")


func _read_catalog_document() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _contains_machine_or_payload_field(value) -> bool:
	if value is Dictionary:
		for key in value:
			var lowered := str(key).to_lower()
			if lowered in ["dialogue", "payload", "payload_bytes", "bytecode", "hex_dump"]:
				return true
			if _contains_machine_or_payload_field(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_machine_or_payload_field(item):
				return true
	elif value is String:
		var text: String = value
		if text.length() >= 3 and text[1] == ":" and (text[2] == "/" or text[2] == "\\"):
			return true
	return false
