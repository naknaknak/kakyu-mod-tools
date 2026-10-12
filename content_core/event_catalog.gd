class_name KakyuEventCatalog
extends RefCounted

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const ContractValues := preload("res://content_core/contract_values.gd")
const GuardFormScript := preload("res://content_core/event_guard_form.gd")

const RETIRED_KEYS := {"analysis_route": true, "caller_route": true}
const CLASSIFICATIONS := {
	"playable_event": true,
	"duplicate_route": true,
	"system_script": true,
	"unreachable_stored_route": true,
	"unresolved_route": true,
}
const PLAYBACK_STATUSES := {
	"minimal_playback": true,
	"analysis_only": true,
	"blocked": true,
	"not_applicable": true,
}
const ACTIVATION_LEVELS := {"confirmed": true, "projected": true, "observed": true, "unresolved": true}
const ACTIVATION_KINDS := {"nested_zero_start": true, "address_entry": true, "explicit_coordinate": true, "host_handoff": true, "unresolved": true}
const PRESET_KINDS := {"original_branch": true, "tool_seeded_analysis": true, "remake_only": true}
const CHOICE_INTERFACES := {"routine40_result": true, "state_write": true, "local_branch": true, "remake_only": true, "unresolved": true}
const TERMINAL_KINDS := {
	"normal_completion": true,
	"early_return": true,
	"rejection_return": true,
	"callee_return_only": true,
	"caller_postlude": true,
	"prefix_end": true,
	"caller_handoff": true,
	"root_replacement": true,
	"unresolved_host_handoff": true,
	"analysis_boundary": true,
}
const TERMINAL_OUTCOMES := {
	"continue": true,
	"normal_completion": true,
	"early_end": true,
	"rejected": true,
	"unresolved": true,
}
const TERMINAL_KIND_OUTCOMES := {
	"normal_completion": ["normal_completion"],
	"early_return": ["early_end"],
	"rejection_return": ["rejected"],
	"callee_return_only": ["continue"],
	"caller_postlude": ["continue"],
	"prefix_end": ["unresolved"],
	"caller_handoff": ["normal_completion"],
	"root_replacement": ["normal_completion"],
	"unresolved_host_handoff": ["unresolved"],
	"analysis_boundary": ["unresolved"],
}
const BLOCKER_CLASSES := {
	"nested_script_call": true,
	"command_0e_host_activation": true,
	"source_state_envelope": true,
	"host_selected_coordinate": true,
	"shared_library_call_frame": true,
	"definition_call_frame": true,
	"routine40_choice_result": true,
	"unsupported_opcode": true,
	"native_presentation": true,
	"whole_event_terminal": true,
	"edited_mes_interface": true,
	"other": true,
}
const MEDIA_POLICIES := {"exact_only": true, "source_bound_allowed": true, "remake_package_allowed": true}
const MES_POLICIES := {"exact_only": true, "equal_length_patch": true, "exact_or_interface_bound": true, "remake_package_allowed": true}
const MANUAL_STATUSES := {"not_required": true, "pending": true, "passed": true, "failed": true}
const STORAGE_WIDTHS := {
	"state_u16": 0xFFFF,
	"state_i32": 0xFFFFFFFF,
	"global_u8": 0xFF,
	"global_i32": 0xFFFFFFFF,
	"relative_u8": 0xFF,
	"banked_u8": 0xFF,
	"banked_u16": 0xFFFF,
	"banked_i32": 0xFFFFFFFF,
}
const CONDITION_OPERATORS := {
	"equals": true,
	"not_equals": true,
	"less_than": true,
	"less_or_equal": true,
	"greater_than": true,
	"greater_or_equal": true,
	"range_inclusive": true,
	"bit_set": true,
	"bit_clear": true,
}
const FORBIDDEN_KEYS := {"dialogue": true, "payload": true, "payload_bytes": true, "bytecode": true, "hex_dump": true}
const BROWSER_FILTER_KEYS := {
	"text": true, "character_id": true, "date_tag": true, "place_id": true,
	"event_type": true, "playback_status": true, "classification": true,
	"blocking_only": true,
}

var last_error := ""
var _document: Dictionary = {}
var _events_by_id: Dictionary = {}


func load_file(path: String) -> Dictionary:
	last_error = ""
	if path.is_empty():
		return _invalid_catalog("Event Catalog path is empty.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _invalid_catalog("Event Catalog could not be opened: %s" % FileAccess.get_open_error())
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _invalid_catalog("Event Catalog must be a JSON object.")
	return validate(parsed)


func validate(document: Dictionary) -> Dictionary:
	last_error = ""
	_document.clear()
	_events_by_id.clear()
	document = document.duplicate(true)
	if str(document.get("schema_version", "")) != ContentCoreVersionScript.EVENT_PLAYER_CATALOG_SCHEMA:
		return _invalid_catalog("Unsupported Event Catalog schema.")
	if not _is_slug(str(document.get("catalog_id", ""))):
		return _invalid_catalog("Event Catalog ID must be lowercase ASCII.")
	if int(document.get("catalog_revision", 0)) <= 0:
		return _invalid_catalog("Event Catalog revision must be positive.")
	if _contains_forbidden_content(document):
		return _invalid_catalog("Event Catalog contains a payload or dialogue field.")
	var profile = document.get("source_profile", null)
	if not profile is Dictionary or not _valid_source_profile(profile):
		return _invalid_catalog(last_error)
	var events = document.get("events", null)
	if not events is Array:
		return _invalid_catalog("Event Catalog events must be an array.")
	var previous_id := ""
	for event_value in events:
		if not event_value is Dictionary:
			return _invalid_catalog("Event Catalog event records must be objects.")
		var event: Dictionary = event_value
		var event_id := str(event.get("event_id", ""))
		if not _is_event_id(event_id) or _events_by_id.has(event_id):
			return _invalid_catalog("Event Catalog contains an invalid or duplicate event_id: %s" % event_id)
		if not previous_id.is_empty() and event_id < previous_id:
			return _invalid_catalog("Event Catalog events must be sorted by event_id.")
		previous_id = event_id
		_events_by_id[event_id] = event
	for event_value in events:
		if not _validate_event(event_value):
			return _invalid_catalog(last_error)
	if not _validate_intro_chain_targets(events):
		return _invalid_catalog(last_error)
	_document = document
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_PLAYER_CATALOG_SCHEMA,
		"catalog_id": str(document.catalog_id),
		"catalog_revision": int(document.catalog_revision),
		"event_count": events.size(),
		"classification_counts": _count_field(events, "classification"),
		"playback_status_counts": _count_field(events, "playback_status"),
		"generated_count": _count_generated(events),
	}


func get_event(event_id: String) -> Dictionary:
	return _events_by_id.get(event_id, {}).duplicate(true)


func get_events() -> Array:
	return _document.get("events", []).duplicate(true)


func get_summary() -> Dictionary:
	if _document.is_empty():
		return {}
	var events: Array = _document.events
	return {
		"schema": ContentCoreVersionScript.EVENT_PLAYER_CATALOG_SCHEMA,
		"catalog_id": str(_document.catalog_id),
		"catalog_revision": int(_document.catalog_revision),
		"event_count": events.size(),
		"classification_counts": _count_field(events, "classification"),
		"playback_status_counts": _count_field(events, "playback_status"),
		"generated_count": _count_generated(events),
	}


func migrate_document(document: Dictionary) -> Dictionary:
	# Migration cannot infer source evidence that an older catalog never held.
	var from_schema := str(document.get("schema_version", ""))
	var legacy_kinds := {
		"kakyu_event_player_catalog/v2": [],
		"kakyu_event_player_catalog/v3": ["bgm_then_handoff"],
		"kakyu_event_player_catalog/v4": ["bgm_then_handoff", "completion_bgm_then_handoff"],
		"kakyu_event_player_catalog/v5": ["bgm_then_handoff", "completion_bgm_then_handoff", "direct_handoff"],
		"kakyu_event_player_catalog/v6": ["bgm_then_handoff", "completion_bgm_then_handoff", "direct_handoff", "caller_choice_projection"],
		"kakyu_event_player_catalog/v7": ["bgm_then_handoff", "completion_bgm_then_handoff", "direct_handoff", "caller_choice_projection", "restore_followup"],
	}
	if not legacy_kinds.has(from_schema):
		return {"ok": false, "error": "Only Event Catalog v2 through v7 can migrate to v8."}
	var events = document.get("events", null)
	if not events is Array:
		return {"ok": false, "error": "Legacy Event Catalog events must be an array."}
	for event in events:
		if not event is Dictionary:
			return {"ok": false, "error": "Legacy Event Catalog event must be an object."}
		if event.has("analysis_route"):
			return {"ok": false, "error": "Legacy catalogs cannot contain bounded analysis-route metadata."}
		if event.has("caller_route"):
			if from_schema == "kakyu_event_player_catalog/v2":
				return {"ok": false, "error": "Event Catalog v2 cannot contain caller-route metadata."}
			if not event.caller_route is Dictionary or event.caller_route.get("kind") not in legacy_kinds[from_schema]:
				return {"ok": false, "error": "Caller-route metadata is unsupported by its legacy catalog schema."}
	var migrated := document.duplicate(true)
	migrated["schema_version"] = ContentCoreVersionScript.EVENT_PLAYER_CATALOG_SCHEMA
	var validator = get_script().new()
	var validation: Dictionary = validator.validate(migrated)
	if not validation.get("ok", false):
		return validation
	return {"ok": true, "from_schema": from_schema, "schema": ContentCoreVersionScript.EVENT_PLAYER_CATALOG_SCHEMA, "document": migrated}


func build_callee_source(event_id: String) -> Dictionary:
	# The callee identity every consumer needs before it may execute an event:
	# which original entry holds it, that entry's hash, and the coordinate the
	# event starts at. Consumers used to freeze their own copy of these.
	if _document.is_empty():
		return {}
	var event: Dictionary = _events_by_id.get(event_id, {})
	if event.is_empty():
		return {}
	var callee: Dictionary = event.source.callee
	if not callee.has("start_coordinate"):
		return {} # An unresolved route has no start coordinate to hand a consumer.
	return {
		"event_id": str(event.event_id),
		"entry": str(callee.entry).to_upper(),
		"entry_sha256": str(callee.entry_sha256),
		"start_coordinate": int(callee.start_coordinate),
	}


func find_callee_source(callee_entry: String) -> Dictionary:
	return build_callee_source(_resolve_callee_owner(callee_entry))


func build_caller_source(event_id: String) -> Dictionary:
	# The caller half of the same `source` block: which original entry dispatches
	# the event, that entry's hash, the coordinate it dispatches from, the
	# coordinate it resumes at and the command it dispatches with. Consumers used
	# to freeze their own copy of these too.
	if _document.is_empty():
		return {}
	var event: Dictionary = _events_by_id.get(event_id, {})
	if event.is_empty():
		return {}
	var caller = event.source.get("caller", null)
	if not caller is Dictionary:
		return {} # The schema lets an unresolved or analysis-only event name no caller.
	return {
		"event_id": str(event.event_id),
		"entry": str(caller.entry).to_upper(),
		"entry_sha256": str(caller.entry_sha256),
		"dispatch_offset": int(caller.dispatch_offset),
		"resume_offset": int(caller.resume_offset),
		"command": int(caller.command),
	}


func find_caller_source(callee_entry: String) -> Dictionary:
	return build_caller_source(_resolve_callee_owner(callee_entry))


func find_source_entry(entry: String) -> Dictionary:
	# The archive identity of an entry the catalog names as some event's
	# required entry: which archive holds it and what it hashes to. This is
	# identity, not requirement — it answers what the entry is, not which events
	# need it, so a consumer that uses a shared entry the catalog records under
	# another event still gets the one identity the archive has for it. A
	# hand-authored row's identity is preferred over an EP-10 generated row's
	# when both name the entry, the same tie-break the callee/caller lookups use.
	if _document.is_empty():
		return {}
	var hand_identity := {}
	var hand_conflict := false
	var hand_found := false
	var any_identity := {}
	var any_conflict := false
	for event in _document.events:
		var is_hand: bool = not event.has("analysis_group")
		for required in event.source.required_entries:
			if str(required.entry).to_upper() != entry.to_upper():
				continue
			var identity := {
				"entry": str(required.entry).to_upper(),
				"archive": str(required.archive),
				"entry_sha256": str(required.entry_sha256),
			}
			if not any_identity.is_empty() and any_identity != identity:
				any_conflict = true
			any_identity = identity
			if is_hand:
				hand_found = true
				if not hand_identity.is_empty() and hand_identity != identity:
					hand_conflict = true
				hand_identity = identity
	if hand_found:
		return {} if hand_conflict else hand_identity
	return {} if any_conflict else any_identity


func _resolve_callee_owner(callee_entry: String) -> String:
	# The event_id a by-name lookup should answer for a callee entry: when the
	# name resolves several catalog rows, the hand-authored row (no
	# `analysis_group` block) is preferred; failing that, one unambiguous
	# EP-10 generated row; otherwise the name stays ambiguous.
	if _document.is_empty():
		return ""
	var upper := callee_entry.to_upper()
	var hand_id := ""
	var hand_count := 0
	var generated_id := ""
	var generated_count := 0
	for event in _document.events:
		if str(event.source.callee.entry).to_upper() != upper:
			continue
		if event.has("analysis_group"):
			generated_count += 1
			generated_id = str(event.event_id)
		else:
			hand_count += 1
			hand_id = str(event.event_id)
	if hand_count == 1:
		return hand_id
	if hand_count == 0 and generated_count == 1:
		return generated_id
	return ""


func build_play_request(event_id: String, preset_id := "", option_id := "", tool_preset := {}) -> Dictionary:
	if _document.is_empty():
		return _play_error("Event Catalog is not loaded.")
	var event: Dictionary = _events_by_id.get(event_id, {})
	if event.is_empty():
		return _play_error("Event Catalog does not contain: %s" % event_id)
	if event.has("analysis_group"):
		return _build_group_route_request(event, event_id, preset_id, option_id, tool_preset)
	return _play_error("Catalog entry has no analysis group; every playable row is generated from one.")


func _build_group_route_request(event: Dictionary, event_id: String, preset_id: String, option_id: String, tool_preset := {}) -> Dictionary:
	# EP-10 unit 2: a promoted analysis-group row is playable whatever its
	# playback status; the group's unbroken caller path is what the player
	# runs, so most of the ordinary refusals (classification, playback
	# status, activation confirmation, a blocking blocker) do not apply here.
	var source: Dictionary = event.get("source", {})
	var caller: Dictionary = source.get("caller", {})
	var callee: Dictionary = source.get("callee", {})
	if caller.is_empty() or not callee.has("start_coordinate"):
		return _play_error("Catalog analysis-group row has no confirmed activation source.")
	var selected_preset := _select_preset(event, preset_id)
	if selected_preset.is_empty():
		return _play_error("Catalog playback has no matching original-branch preset.")
	# EP-10 unit 3: the guard form's starting state is a tool-seeded preset,
	# not a catalog preset; it replaces the composed preset in the request
	# but names the catalog preset it started from as `base_preset_id`, so
	# the group/route/variant can still be resolved from that preset's notes.
	# Round 3 code review, item 7: the accepted preset is normalised here -
	# only its writes come from the caller's dictionary, nothing else.
	if not tool_preset.is_empty():
		if str(tool_preset.get("kind", "")) != "tool_seeded_analysis" or not _valid_tool_preset_writes(tool_preset.get("writes", null)):
			return _play_error("The tool-seeded starting state is malformed.")
		selected_preset = GuardFormScript.tool_seeded_preset("tool-seeded", (tool_preset.writes as Array).duplicate(true))
		selected_preset["base_preset_id"] = preset_id
	var terminal_contract := build_terminal_contract(event_id)
	if not terminal_contract.get("ok", false):
		return _play_error(str(terminal_contract.get("error", "Catalog terminal contract is invalid.")))
	var choices: Array = event.get("choices", []).duplicate(true)
	var selection: Dictionary = {}
	if not choices.is_empty():
		var choice: Dictionary = choices[0]
		var requested_option := str(option_id).strip_edges()
		var selected_option: Dictionary = {}
		if requested_option.is_empty():
			# Default to the first *measured* option (one whose terminal_ids is
			# non-empty); an unmeasured option is never the silent default.
			for untyped_option in choice.get("options", []):
				var option: Dictionary = untyped_option
				if not (option.get("terminal_ids", []) as Array).is_empty():
					selected_option = option
					break
			if selected_option.is_empty():
				var options: Array = choice.get("options", [])
				if not options.is_empty():
					selected_option = options[0]
		else:
			for untyped_option in choice.get("options", []):
				var option: Dictionary = untyped_option
				if str(option.get("option_id", "")) == requested_option:
					selected_option = option
					break
		if selected_option.is_empty():
			return _play_error("Catalog analysis-group choice option is unknown: %s" % option_id)
		if (selected_option.get("terminal_ids", []) as Array).is_empty():
			return _play_error("This answer was not measured; no route reaches a terminal for it.")
		selection = {
			"choice_id": str(choice.choice_id),
			"option_id": str(selected_option.option_id),
			"result_value": int(selected_option.result_value),
			"boundary_offset": int(choice.boundary_offset),
			"owner_entry": str(choice.owner_entry),
			"terminal_ids": (selected_option.get("terminal_ids", []) as Array).duplicate(true),
		}
	elif not str(option_id).strip_edges().is_empty():
		return _play_error("Catalog analysis-group row has no choices to select an option from.")
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_CATALOG_PLAY_REQUEST_SCHEMA,
		"catalog_id": str(_document.catalog_id),
		"catalog_revision": int(_document.catalog_revision),
		"source_profile": _document.get("source_profile", {}).duplicate(true),
		"event_id": event_id,
		"title": str(event.get("display", {}).get("title", event_id)),
		"playback_status": str(event.playback_status),
		"activation_kind": str(event.get("activation", {}).get("kind", "")),
		"execution_model": "group_route",
		"callee": {
			"archive": str(callee.archive),
			"entry": str(callee.entry),
			"entry_sha256": str(callee.entry_sha256),
			"start_coordinate": int(callee.start_coordinate),
		},
		"required_entries": source.get("required_entries", []).duplicate(true),
		"preset": selected_preset.duplicate(true),
		"compatibility": event.get("compatibility", {}).duplicate(true),
		"terminal_contract": terminal_contract,
		"analysis_group": event.get("analysis_group", {}).duplicate(true),
		"choices": choices,
		"terminals": event.get("terminals", []).duplicate(true),
		"selection": selection,
	}


## The event's preset named by `preset_id`, or (an empty `preset_id`) the
## first `original_branch` preset - shared by `build_play_request`'s
## ordinary and group-route paths. `{}` when none matches.
func _select_preset(event: Dictionary, preset_id: String) -> Dictionary:
	var requested_preset := str(preset_id).strip_edges()
	for untyped_preset in event.get("presets", []):
		var preset: Dictionary = untyped_preset
		if (
			(not requested_preset.is_empty() and str(preset.get("preset_id", "")) == requested_preset)
			or (requested_preset.is_empty() and str(preset.get("kind", "")) == "original_branch")
		):
			return preset
	return {}


## Whether `writes` is an Array of unique `(storage, bank, index)` write
## records - the shape `KakyuEventGuardForm.writes` produces - each valid by
## `_valid_state_value` (a known storage, `bank`/`index` >= 0, `value`
## within that storage's width): an overflowing value is refused, never
## masked.
func _valid_tool_preset_writes(writes) -> bool:
	if not writes is Array or (writes as Array).is_empty():
		return false
	var seen := {}
	for write_value in writes:
		if not write_value is Dictionary:
			return false
		var write: Dictionary = write_value
		if not _valid_state_value(write):
			return false
		var write_key := GuardFormScript.key(str(write.storage), int(write.bank), int(write.index))
		if seen.has(write_key):
			return false
		seen[write_key] = true
	return true


func build_terminal_contract(event_id: String) -> Dictionary:
	if _document.is_empty():
		return _play_error("Event Catalog is not loaded.")
	var event: Dictionary = _events_by_id.get(event_id, {})
	if event.is_empty():
		return _play_error("Event Catalog does not contain: %s" % event_id)
	var stages: Array[Dictionary] = []
	for terminal_value in event.get("terminals", []):
		var terminal: Dictionary = terminal_value
		var stage := terminal.duplicate(true)
		stage["phase"] = _terminal_phase(str(terminal.kind))
		stage["route_ended"] = str(terminal.outcome) in ["normal_completion", "early_end", "rejected"]
		stage["display"] = _terminal_display(str(terminal.outcome))
		stage["outer_host_executed"] = false
		stages.append(stage)
	stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sequence_a := int(a.sequence)
		var sequence_b := int(b.sequence)
		return sequence_a < sequence_b or (sequence_a == sequence_b and str(a.terminal_id) < str(b.terminal_id))
	)
	return {
		"ok": true,
		"schema": ContentCoreVersionScript.EVENT_CATALOG_TERMINAL_CONTRACT_SCHEMA,
		"event_id": event_id,
		"stages": stages,
	}


func match_terminal(event_id: String, observation: Dictionary) -> Dictionary:
	var contract := build_terminal_contract(event_id)
	if not contract.get("ok", false):
		return contract
	return match_terminal_contract(contract, observation)


func match_terminal_contract(contract: Dictionary, observation: Dictionary) -> Dictionary:
	if (
		str(contract.get("schema", "")) != ContentCoreVersionScript.EVENT_CATALOG_TERMINAL_CONTRACT_SCHEMA
		or not contract.get("stages", null) is Array
		or not _is_event_id(str(contract.get("event_id", "")))
	):
		return _play_error("Terminal contract is invalid.")
	var authoritative := build_terminal_contract(str(contract.event_id))
	if not authoritative.get("ok", false) or contract != authoritative:
		return _play_error("Terminal contract changed after it was issued by the loaded catalog.")
	var owner_entry := str(observation.get("owner_entry", "")).to_upper()
	var runtime_status := str(observation.get("runtime_status", ""))
	var offset := int(observation.get("offset", -1))
	if owner_entry.is_empty() or runtime_status.is_empty() or offset < 0:
		return _play_error("Terminal observation is incomplete.")
	var coordinate_candidate := false
	for stage_value in contract.stages:
		if not stage_value is Dictionary:
			return _play_error("Terminal contract contains an invalid stage.")
		var stage: Dictionary = stage_value
		if str(stage.owner_entry).to_upper() != owner_entry or int(stage.offset) != offset:
			continue
		coordinate_candidate = true
		if str(stage.runtime_status) != runtime_status:
			continue
		var expected_target := str(stage.get("next_target", "")).to_upper()
		if not expected_target.is_empty() and str(observation.get("next_target", "")).to_upper() != expected_target:
			continue
		if not _terminal_state_matches(stage.get("required_state", []), observation.get("state_values", [])):
			continue
		var matched := stage.duplicate(true)
		matched["ok"] = true
		matched["schema"] = ContentCoreVersionScript.EVENT_CATALOG_TERMINAL_CONTRACT_SCHEMA
		matched["event_id"] = str(contract.event_id)
		return matched
	return _play_error(
		"Terminal observation changed at a cataloged coordinate."
		if coordinate_candidate
		else "Terminal observation is not cataloged for this event."
	)


func build_browser_rows(filters: Dictionary = {}) -> Dictionary:
	if _document.is_empty():
		return _error("Event Catalog is not loaded.")
	for key in filters:
		if not BROWSER_FILTER_KEYS.has(str(key)):
			return _error("Unknown Event Catalog browser filter: %s" % str(key))
	var text_filter := str(filters.get("text", "")).strip_edges().to_lower()
	var character_filter := str(filters.get("character_id", "")).strip_edges().to_lower()
	var date_filter := str(filters.get("date_tag", "")).strip_edges().to_lower()
	var place_filter := str(filters.get("place_id", "")).strip_edges().to_lower()
	var type_filter := str(filters.get("event_type", "")).strip_edges().to_lower()
	var status_filter := str(filters.get("playback_status", "")).strip_edges().to_lower()
	var classification_filter := str(filters.get("classification", "")).strip_edges().to_lower()
	if not status_filter.is_empty() and not PLAYBACK_STATUSES.has(status_filter):
		return _error("Event Catalog browser playback status is invalid.")
	if not classification_filter.is_empty() and not CLASSIFICATIONS.has(classification_filter):
		return _error("Event Catalog browser classification is invalid.")
	if filters.has("blocking_only") and not filters.blocking_only is bool:
		return _error("Event Catalog browser blocking_only filter must be boolean.")
	var rows: Array[Dictionary] = []
	for untyped_event in _document.events:
		var event: Dictionary = untyped_event
		var row := _browser_row(event)
		if _browser_row_matches(row, text_filter, character_filter, date_filter, place_filter, type_filter, status_filter, classification_filter, bool(filters.get("blocking_only", false))):
			rows.append(row)
	return {"ok": true, "schema": ContentCoreVersionScript.EVENT_CATALOG_BROWSER_SCHEMA, "catalog_id": str(_document.catalog_id), "catalog_revision": int(_document.catalog_revision), "visible_count": rows.size(), "total_count": _document.events.size(), "rows": rows}


func _browser_row(event: Dictionary) -> Dictionary:
	var display: Dictionary = event.display
	var blockers: Array[Dictionary] = []
	var has_blocking := false
	for untyped_blocker in event.blockers:
		var blocker: Dictionary = untyped_blocker
		var summary := {"blocker_id": str(blocker.blocker_id), "class": str(blocker.get("class", "other")), "blocks_playback": bool(blocker.get("blocks_playback", false)), "summary": str(blocker.get("summary", "")), "todo_id": str(blocker.get("todo_id", ""))}
		blockers.append(summary)
		has_blocking = has_blocking or bool(summary.blocks_playback)
	var recommended_preset := {}
	for untyped_preset in event.presets:
		var preset: Dictionary = untyped_preset
		if str(preset.get("kind", "")) == "original_branch":
			recommended_preset = {"preset_id": str(preset.preset_id), "label": str(preset.get("label", preset.preset_id)), "kind": "original_branch"}
			break
	return {
		"event_id": str(event.event_id), "title": str(display.title),
		"character_ids": _normalized_string_array(display.get("character_ids", [])), "categories": _normalized_string_array(display.get("categories", [])),
		"date_tags": _normalized_string_array(display.get("date_tags", [])), "place_ids": _normalized_string_array(display.get("place_ids", [])),
		"event_types": _normalized_string_array(display.get("event_types", display.get("categories", []))),
		"classification": str(event.classification), "playback_status": str(event.playback_status), "activation_kind": str(event.activation.kind), "evidence_level": str(event.activation.evidence_level),
		"recommended_preset": recommended_preset, "preset_count": event.presets.size(), "branch_count": event.branches.size(), "choice_count": event.choices.size(), "terminal_count": event.terminals.size(),
		"compatibility": event.compatibility.duplicate(true), "blockers": blockers, "has_blocking_blocker": has_blocking,
	}


func _browser_row_matches(row: Dictionary, text_filter: String, character_filter: String, date_filter: String, place_filter: String, type_filter: String, status_filter: String, classification_filter: String, blocking_only: bool) -> bool:
	if not character_filter.is_empty() and character_filter not in row.character_ids: return false
	if not date_filter.is_empty() and date_filter not in row.date_tags: return false
	if not place_filter.is_empty() and place_filter not in row.place_ids: return false
	if not type_filter.is_empty() and type_filter not in row.event_types: return false
	if not status_filter.is_empty() and str(row.playback_status) != status_filter: return false
	if not classification_filter.is_empty() and str(row.classification) != classification_filter: return false
	if blocking_only and not bool(row.has_blocking_blocker): return false
	if text_filter.is_empty(): return true
	var searchable := [str(row.event_id), str(row.title), str(row.playback_status), str(row.classification)]
	searchable.append_array(row.character_ids)
	searchable.append_array(row.categories)
	searchable.append_array(row.date_tags)
	searchable.append_array(row.place_ids)
	searchable.append_array(row.event_types)
	for blocker in row.blockers: searchable.append(str(blocker.summary))
	for value in searchable:
		if text_filter in str(value).to_lower(): return true
	return false


func _normalized_string_array(values) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values: result.append(str(value).to_lower())
	return result


func _valid_source_profile(profile: Dictionary) -> bool:
	if not _is_slug(str(profile.get("profile_id", ""))):
		last_error = "Event Catalog source profile ID is invalid."
		return false
	var archive = profile.get("mes_archive", null)
	if not archive is Dictionary or str(archive.get("archive", "")).to_lower() != "mes.arc" or not ContractValues.is_sha256(str(archive.get("sha256", ""))):
		last_error = "Event Catalog source mes.arc binding is invalid."
		return false
	var audit = profile.get("executable_audit", null)
	if not audit is Dictionary:
		last_error = "Event Catalog executable audit record is missing."
		return false
	var runtime_sha := str(audit.get("runtime_sha256", ""))
	if not runtime_sha.is_empty() and not ContractValues.is_sha256(runtime_sha):
		last_error = "Event Catalog executable audit hash is invalid."
		return false
	return true


func _validate_event(event: Dictionary) -> bool:
	var event_id := str(event.event_id)
	for retired_key in RETIRED_KEYS:
		if event.has(retired_key):
			return _fail("%s carries a retired shape: %s" % [event_id, retired_key])
	var classification := str(event.get("classification", ""))
	var playback_status := str(event.get("playback_status", ""))
	if not CLASSIFICATIONS.has(classification) or not PLAYBACK_STATUSES.has(playback_status):
		return _fail("%s has an invalid classification or playback status." % event_id)
	var canonical_id := str(event.get("canonical_event_id", ""))
	if classification == "duplicate_route":
		if not _events_by_id.has(canonical_id) or str(_events_by_id[canonical_id].get("classification", "")) == "duplicate_route":
			return _fail("%s has an invalid canonical event reference." % event_id)
	elif not canonical_id.is_empty():
		return _fail("%s unexpectedly defines canonical_event_id." % event_id)
	if playback_status == "not_applicable" and classification not in ["duplicate_route", "system_script"]:
		return _fail("%s cannot use not_applicable playback status." % event_id)
	var display = event.get("display", null)
	if not display is Dictionary or str(display.get("title", "")).strip_edges().is_empty():
		return _fail("%s display metadata is incomplete." % event_id)
	for list_key in ["character_ids", "categories"]:
		if not display.get(list_key, null) is Array:
			return _fail("%s display %s must be an array." % [event_id, list_key])
	var source = event.get("source", null)
	if not source is Dictionary or not _validate_source(event_id, source, classification, playback_status):
		return false
	var activation = event.get("activation", null)
	if not activation is Dictionary or not ACTIVATION_KINDS.has(str(activation.get("kind", ""))) or not ACTIVATION_LEVELS.has(str(activation.get("evidence_level", ""))):
		return _fail("%s activation metadata is invalid." % event_id)
	if not _valid_refs(activation.get("document_refs", [])):
		return _fail("%s activation references are unsafe." % event_id)
	var ids := {}
	for pair in [["presets", "preset_id"], ["branches", "branch_id"], ["choices", "choice_id"], ["resources", "resource_id"], ["terminals", "terminal_id"], ["blockers", "blocker_id"]]:
		var values = event.get(pair[0], null)
		if not values is Array:
			return _fail("%s %s must be an array." % [event_id, pair[0]])
		ids[pair[0]] = _collect_ids(values, pair[1])
		if ids[pair[0]] == null:
			return _fail("%s has an invalid or duplicate %s." % [event_id, pair[1]])
	if not _validate_presets(event_id, event.presets, ids.branches):
		return false
	if not _validate_branches(event_id, event.branches, ids.resources, ids.terminals):
		return false
	if not _validate_choices(event_id, event.choices, ids.branches, ids.terminals):
		return false
	if not _validate_resources(event_id, event.resources, ids.branches):
		return false
	if not _validate_terminals(event_id, event.terminals):
		return false
	if event.has("analysis_group") and not _validate_analysis_group(event_id, event.analysis_group):
		return false
	var blocking := false
	for blocker_value in event.blockers:
		var blocker: Dictionary = blocker_value
		if not BLOCKER_CLASSES.has(str(blocker.get("class", ""))) or not _valid_offset(blocker.get("offset", -1)) or not _valid_refs(blocker.get("document_refs", [])):
			return _fail("%s has an invalid blocker." % event_id)
		blocking = blocking or bool(blocker.get("blocks_playback", false))
	var compatibility = event.get("compatibility", null)
	if not compatibility is Dictionary or not MEDIA_POLICIES.has(str(compatibility.get("media_replacements", ""))) or not MES_POLICIES.has(str(compatibility.get("mes_replacements", ""))):
		return _fail("%s compatibility metadata is invalid." % event_id)
	var verification = event.get("verification", null)
	if not verification is Dictionary or not _validate_verification(event_id, verification):
		return false
	if playback_status == "minimal_playback":
		if blocking or str(activation.evidence_level) == "unresolved" or str(activation.kind) == "unresolved":
			return _fail("%s cannot claim minimal playback while blocked or unresolved." % event_id)
		for choice_value in event.choices:
			if str(choice_value.get("result_interface", "")) == "unresolved":
				return _fail("%s cannot claim minimal playback with unresolved choices." % event_id)
	return true


func _validate_analysis_group(event_id: String, block) -> bool:
	if not block is Dictionary:
		return _fail("%s analysis_group must be an object." % event_id)
	var definition_id := str(block.get("definition_id", ""))
	if definition_id.is_empty() or not _is_definition_id(definition_id):
		return _fail("%s analysis_group definition_id is invalid." % event_id)
	var groups = block.get("groups", null)
	if not groups is Array or groups.is_empty():
		return _fail("%s analysis_group groups must be a nonempty array." % event_id)
	for group_value in groups:
		if not group_value is Dictionary:
			return _fail("%s analysis_group group entry must be an object." % event_id)
		var group: Dictionary = group_value
		var route_ids = group.get("route_ids", null)
		if (
			str(group.get("group_id", "")).is_empty()
			or not ContractValues.is_sha256(str(group.get("profile_sha256", "")))
			or not route_ids is Array or route_ids.is_empty()
		):
			return _fail("%s analysis_group group entry is invalid." % event_id)
		for route_id in route_ids:
			if not route_id is String or str(route_id).is_empty():
				return _fail("%s analysis_group route_ids must be nonempty strings." % event_id)
	return true


func _is_definition_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return true


func _count_generated(events: Array) -> int:
	var count := 0
	for event in events:
		if (event as Dictionary).has("analysis_group"):
			count += 1
	return count


func _validate_source(event_id: String, source: Dictionary, classification: String, playback_status: String) -> bool:
	var caller = source.get("caller", null)
	if caller == null:
		if classification != "unresolved_route" and playback_status != "analysis_only":
			return _fail("%s requires caller evidence." % event_id)
	elif not caller is Dictionary or not _valid_entry_ref(caller, true):
		return _fail("%s caller evidence is invalid." % event_id)
	var callee = source.get("callee", null)
	if not callee is Dictionary or not _valid_entry_ref(callee, false):
		return _fail("%s callee evidence is invalid." % event_id)
	if not callee.has("start_coordinate") and classification != "unresolved_route":
		return _fail("%s requires a callee start coordinate." % event_id)
	if callee.has("start_coordinate") and not _valid_offset(callee.start_coordinate):
		return _fail("%s callee start coordinate is invalid." % event_id)
	if int(callee.get("address_index", -1)) < -1:
		return _fail("%s callee address index is invalid." % event_id)
	var required = source.get("required_entries", null)
	if not required is Array:
		return _fail("%s required_entries must be an array." % event_id)
	for entry_value in required:
		if not entry_value is Dictionary or not _valid_entry_ref(entry_value, false) or str(entry_value.get("role", "")).is_empty():
			return _fail("%s has an invalid required entry." % event_id)
	return true


func _valid_entry_ref(value: Dictionary, caller: bool) -> bool:
	if not _safe_leaf(str(value.get("archive", ""))) or not _safe_leaf(str(value.get("entry", ""))) or not ContractValues.is_sha256(str(value.get("entry_sha256", ""))):
		return false
	if caller:
		return _valid_offset(value.get("dispatch_offset", -1)) and _valid_offset(value.get("resume_offset", -1)) and int(value.get("command", -1)) >= 0
	return true


func _validate_presets(event_id: String, presets: Array, branch_ids: Dictionary) -> bool:
	for preset_value in presets:
		var preset: Dictionary = preset_value
		if not PRESET_KINDS.has(str(preset.get("kind", ""))):
			return _fail("%s has an invalid preset kind." % event_id)
		for write_value in preset.get("writes", []):
			if not write_value is Dictionary or not _valid_state_value(write_value):
				return _fail("%s has an invalid preset write." % event_id)
		for branch_id in preset.get("expected_branch_ids", []):
			if not branch_ids.has(str(branch_id)):
				return _fail("%s preset references an unknown branch." % event_id)
	return true


func _validate_branches(event_id: String, branches: Array, resource_ids: Dictionary, terminal_ids: Dictionary) -> bool:
	for branch_value in branches:
		var branch: Dictionary = branch_value
		for condition_value in branch.get("conditions", []):
			if not condition_value is Dictionary or not _valid_condition(condition_value):
				return _fail("%s has an invalid branch condition." % event_id)
		for resource_id in branch.get("resource_ids", []):
			if not resource_ids.has(str(resource_id)):
				return _fail("%s branch references an unknown resource." % event_id)
		for terminal_id in branch.get("terminal_ids", []):
			if not terminal_ids.has(str(terminal_id)):
				return _fail("%s branch references an unknown terminal." % event_id)
	return true


func _validate_choices(event_id: String, choices: Array, branch_ids: Dictionary, terminal_ids: Dictionary) -> bool:
	for choice_value in choices:
		var choice: Dictionary = choice_value
		if not _safe_leaf(str(choice.get("owner_entry", ""))) or not _valid_offset(choice.get("boundary_offset", -1)) or not CHOICE_INTERFACES.has(str(choice.get("result_interface", ""))):
			return _fail("%s has invalid choice metadata." % event_id)
		var option_ids := {}
		for option_value in choice.get("options", []):
			if not option_value is Dictionary:
				return _fail("%s choice option is invalid." % event_id)
			var option_id := str(option_value.get("option_id", ""))
			if not _is_slug(option_id) or option_ids.has(option_id):
				return _fail("%s has an invalid or duplicate choice option." % event_id)
			option_ids[option_id] = true
			var branch_id := str(option_value.get("branch_id", ""))
			if not branch_id.is_empty() and not branch_ids.has(branch_id):
				return _fail("%s choice option references an unknown branch." % event_id)
			for terminal_id in option_value.get("terminal_ids", []):
				if not terminal_ids.has(str(terminal_id)):
					return _fail("%s choice option references an unknown terminal." % event_id)
	return true


func _validate_resources(event_id: String, resources: Array, branch_ids: Dictionary) -> bool:
	for resource_value in resources:
		var resource: Dictionary = resource_value
		if not _safe_leaf(str(resource.get("request_entry", ""))) or not _valid_offset(resource.get("request_offset", -1)) or not _safe_leaf(str(resource.get("entry", ""))):
			return _fail("%s resource metadata is invalid." % event_id)
		var sha := str(resource.get("original_entry_sha256", ""))
		if not sha.is_empty() and not ContractValues.is_sha256(sha):
			return _fail("%s resource hash is invalid." % event_id)
		for branch_id in resource.get("branch_ids", []):
			if not branch_ids.has(str(branch_id)):
				return _fail("%s resource references an unknown branch." % event_id)
	return true


func _validate_terminals(event_id: String, terminals: Array) -> bool:
	for terminal_value in terminals:
		var terminal: Dictionary = terminal_value
		var kind := str(terminal.get("kind", ""))
		var outcome := str(terminal.get("outcome", ""))
		var sequence := int(terminal.get("sequence", -1))
		if (
			not TERMINAL_KINDS.has(kind)
			or not TERMINAL_OUTCOMES.has(outcome)
			or outcome not in TERMINAL_KIND_OUTCOMES.get(kind, [])
			or not _safe_leaf(str(terminal.get("owner_entry", "")))
			or not _valid_offset(terminal.get("offset", -1))
			or str(terminal.get("runtime_status", "")).strip_edges().is_empty()
			or sequence < 0
			or not terminal.get("required_state", []) is Array
		):
			return _fail("%s terminal metadata is invalid." % event_id)
		for assertion_value in terminal.get("required_state", []):
			if not assertion_value is Dictionary or not _valid_condition(assertion_value, true):
				return _fail("%s terminal state assertion is invalid." % event_id)
	return true


func _catalog_intro_index(events: Array) -> Dictionary:
	# `(CALLER_ENTRY_UPPER, dispatch_offset) -> callee_entry`, built from
	# every row's `source.caller.entry`/`source.caller.dispatch_offset` and
	# `source.callee.entry`. Port of
	# `tools.event_outcome_vocabulary.catalog_intro_index`.
	var index := {}
	for event_value in events:
		var event: Dictionary = event_value
		var source = event.get("source", {})
		if not source is Dictionary:
			continue
		var caller = source.get("caller", null)
		var callee = source.get("callee", null)
		if not caller is Dictionary or not callee is Dictionary:
			continue
		var entry := str(caller.get("entry", "")).to_upper()
		var callee_entry := str(callee.get("entry", ""))
		if entry.is_empty() or callee_entry.is_empty() or not caller.has("dispatch_offset"):
			continue
		var key := "%s:%d" % [entry, int(caller.dispatch_offset)]
		index[key] = callee_entry
	return index


func _validate_intro_chain_targets(events: Array) -> bool:
	# Fail closed (owner ruling 2026-09-23, EP-03 step 2): an
	# `analysis_boundary`/`script_dispatch_boundary` terminal carrying a
	# non-empty `next_target` must name the callee entry of a row whose
	# `source.caller` entry and `dispatch_offset` equal the terminal's own
	# `owner_entry`/`offset` - the only shape the promotion tool writes.
	var index := _catalog_intro_index(events)
	for event_value in events:
		var event: Dictionary = event_value
		var event_id := str(event.get("event_id", ""))
		for terminal_value in event.get("terminals", []):
			var terminal: Dictionary = terminal_value
			if str(terminal.get("kind", "")) != "analysis_boundary":
				continue
			if str(terminal.get("runtime_status", "")) != "script_dispatch_boundary":
				continue
			var next_target := str(terminal.get("next_target", ""))
			if next_target.is_empty():
				continue
			var owner_entry := str(terminal.get("owner_entry", "")).to_upper()
			var key := "%s:%d" % [owner_entry, int(terminal.get("offset", -1))]
			var expected = index.get(key, null)
			if expected == null or str(expected).to_upper() != next_target.to_upper():
				return _fail("%s script_dispatch_boundary terminal next_target does not match another event's intro dispatch." % event_id)
	return true


func _route_mes_entry(value: String) -> bool:
	return _safe_leaf(value) and value.get_extension().to_lower() == "mes" and not value.get_basename().is_empty() and value.to_utf8_buffer().size() == value.length()


func _terminal_phase(kind: String) -> String:
	match kind:
		"callee_return_only":
			return "callee_return"
		"caller_postlude":
			return "caller_post_event_presentation"
		"caller_handoff", "unresolved_host_handoff":
			return "outer_host_handoff"
		"root_replacement":
			return "root_replacement"
		"normal_completion", "early_return", "rejection_return":
			return "event_terminal"
		"prefix_end":
			return "prefix_end"
		_:
			return "analysis_boundary"


func _terminal_display(outcome: String) -> String:
	match outcome:
		"normal_completion":
			return "event_complete"
		"early_end":
			return "event_ended_early"
		"rejected":
			return "event_rejected"
		"continue":
			return "continue"
		_:
			return "unresolved"


func _terminal_state_matches(required_values, observed_values) -> bool:
	if not required_values is Array or not observed_values is Array:
		return false
	var observed := {}
	for value in observed_values:
		if not value is Dictionary:
			return false
		var key := "%s:%d:%d" % [str(value.get("storage", "")), int(value.get("bank", 0)), int(value.get("index", -1))]
		observed[key] = int(value.get("value", -1))
	for required_value in required_values:
		var required: Dictionary = required_value
		var key := "%s:%d:%d" % [str(required.storage), int(required.get("bank", 0)), int(required.index)]
		if not observed.has(key) or not _condition_matches(int(observed[key]), required):
			return false
	return true


func _condition_matches(actual: int, condition: Dictionary) -> bool:
	var expected := int(condition.get("value", 0))
	match str(condition.get("operator", "")):
		"equals": return actual == expected
		"not_equals": return actual != expected
		"less_than": return actual < expected
		"less_or_equal": return actual <= expected
		"greater_than": return actual > expected
		"greater_or_equal": return actual >= expected
		"range_inclusive":
			var values: Array = condition.get("values", [])
			return values.size() == 2 and actual >= int(values[0]) and actual <= int(values[1])
		"bit_set": return (actual & expected) == expected
		"bit_clear": return (actual & expected) == 0
	return false


func _validate_verification(event_id: String, verification: Dictionary) -> bool:
	for automated_value in verification.get("automated", []):
		if not automated_value is Dictionary or not _safe_repo_ref(str(automated_value.get("path", ""))):
			return _fail("%s automated validator path is unsafe." % event_id)
	for manual_value in verification.get("manual", []):
		if not manual_value is Dictionary or not MANUAL_STATUSES.has(str(manual_value.get("status", ""))):
			return _fail("%s manual verification status is invalid." % event_id)
	return true


func _valid_state_value(value: Dictionary) -> bool:
	var storage := str(value.get("storage", ""))
	if not STORAGE_WIDTHS.has(storage) or int(value.get("bank", -1)) < 0 or int(value.get("index", -1)) < 0:
		return false
	var stored := int(value.get("value", -1))
	return stored >= 0 and stored <= int(STORAGE_WIDTHS[storage])


func _valid_condition(value: Dictionary, terminal := false) -> bool:
	if not _valid_state_value({"storage": value.get("storage", ""), "bank": value.get("bank", -1), "index": value.get("index", -1), "value": value.get("value", 0)}):
		return false
	if not CONDITION_OPERATORS.has(str(value.get("operator", ""))):
		return false
	if terminal:
		return value.has("value")
	var values = value.get("values", null)
	if values != null:
		if not values is Array or values.is_empty():
			return false
		for item in values:
			if int(item) < 0 or int(item) > int(STORAGE_WIDTHS[str(value.storage)]):
				return false
		return true
	return value.has("value") and int(value.value) >= 0 and int(value.value) <= int(STORAGE_WIDTHS[str(value.storage)])


func _collect_ids(values: Array, key: String):
	var result := {}
	for value in values:
		if not value is Dictionary:
			return null
		var id := str(value.get(key, ""))
		if not _is_slug(id) or result.has(id):
			return null
		result[id] = true
	return result


func _count_field(events: Array, key: String) -> Dictionary:
	var counts := {}
	for event in events:
		var value := str(event.get(key, ""))
		counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _contains_forbidden_content(value) -> bool:
	if value is Dictionary:
		for key in value:
			if FORBIDDEN_KEYS.has(str(key).to_lower()) or _contains_forbidden_content(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_content(item):
				return true
	return false


func _valid_refs(value) -> bool:
	if not value is Array:
		return false
	for item in value:
		if not _safe_repo_ref(str(item)):
			return false
	return true


func _safe_repo_ref(value: String) -> bool:
	if value.is_empty() or value.contains("..") or value.begins_with("/") or value.begins_with("\\"):
		return false
	if value.length() >= 2 and value[1] == ":":
		return false
	return value.begins_with("res://") or value.begins_with("docs/") or value.begins_with("tools/") or value.begins_with("tests/")


func _safe_leaf(value: String) -> bool:
	return not value.is_empty() and not value.contains("/") and not value.contains("\\") and not value.contains("..") and not value.contains(":")


## The catalog's slug rule: a non-empty lower-case ASCII id of letters, digits,
## `-` and `_`. Shared so a caller that must agree with the catalog (the playback
## package's catalog binding) calls it instead of copying the character set.
static func is_slug(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-_":
			return false
	return true


func _is_slug(value: String) -> bool:
	return is_slug(value)


func _is_event_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower() or value.begins_with("/") or value.ends_with("/") or value.contains("//") or value.contains(".."):
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-_/":
			return false
	return true


func _valid_offset(value) -> bool:
	return (value is int or value is float) and int(value) >= 0


func _fail(message: String) -> bool:
	last_error = message
	return false


func _invalid_catalog(message: String) -> Dictionary:
	_document.clear()
	_events_by_id.clear()
	return _error(message)


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "schema": ContentCoreVersionScript.EVENT_PLAYER_CATALOG_SCHEMA, "error": message}


func _play_error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "schema": ContentCoreVersionScript.EVENT_CATALOG_PLAY_REQUEST_SCHEMA, "error": message}


static func source_members_for_events(events: Array[Dictionary]) -> Array[Dictionary]:
	var members: Array[Dictionary] = []
	var seen: Dictionary = {}
	for untyped_event in events:
		var source: Dictionary = (untyped_event as Dictionary).get("source", {})
		var callee: Dictionary = source.get("callee", {})
		if str(callee.get("archive", "")) == "mes.arc" and not seen.has(str(callee.entry)):
			seen[str(callee.entry)] = true
			members.append({
				"entry": str(callee.entry),
				"entry_sha256": str(callee.entry_sha256),
				"role": "event_entry",
			})
		for untyped_required in source.get("required_entries", []):
			var required: Dictionary = untyped_required
			if str(required.get("archive", "")) != "mes.arc":
				continue
			if seen.has(str(required.entry)):
				continue
			seen[str(required.entry)] = true
			members.append({
				"entry": str(required.entry),
				"entry_sha256": str(required.entry_sha256),
				"role": str(required.get("role", "")),
			})
	return members
