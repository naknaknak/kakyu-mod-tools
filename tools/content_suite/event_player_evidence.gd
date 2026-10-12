class_name KakyuEventPlayerEvidence
extends RefCounted

## TD-11 unit 2: the Event Player's read-only source and run state, held by
## reference so the eleven generic evidence helpers (and the per-event static
## functions that call them) can read it without the scene script. Built
## fresh per call by the player's `_evidence()`; a caller never holds a stale
## context.

const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const AUDITED_MES_ARCHIVE_SHA256 := "31a95b31cb0f1051cf973a4dba4f4a5405671e4488240adfafb9b02290986aa6"
const AUDITED_STARTUP_CONTEXT_SELECTORS := [18, 81, 26, 11, 12, 14, 15, 17, 21, 22, 23, 20, 80, 99]
const CATALOG_SOURCED_ENTRY := "event_catalog"
const EVENTD14_COMPLETION_STATE_INDEX := 763
const EVENTD14_CHOICE_BOUNDARY := 0x0942
const CONFIRMED_ADDRESS_CATALOGS := {
	"EVENTD06.MES": {
		"label": "Maki host-selected dialogue fragments",
		"source": CATALOG_SOURCED_ENTRY,
		"entry_count": 67,
		"caller_op": "script_handoff_marker",
		"setup_start_coordinate": 0x0008,
		"setup_entry_offset": 0x0008,
		"setup_entry_index": 0,
		"setup_start_kind": "source_table_entry",
		"setup_shared_routine": 28,
		"setup_shared_offset": 0x00E6,
		"setup_shared_resume": 0x00EB,
		"setup_native_offset": 0x0105,
		"setup_native_resume": 0x0110,
		"setup_native_record_count": 3,
		# Core 0.316.0 (2026-09-13): the two "native presentation boundaries" this
		# setup once stopped at were a byte inside a system call and the call
		# System.function[12](30) at 0x0B52; the setup runs through both to the
		# extension terminal.
		"setup_native_presentation_boundaries": [],
		"setup_extension_mmo": "D07.MMO",
		"setup_extension_terminals": [
			{"status": "shared_routine_boundary", "offset": 0x0C0E, "resume": 0x0C13, "routine_id": 21, "branch_global_u8_4000": 0},
			{"status": "shared_routine_boundary", "offset": 0x0C1E, "resume": 0x0C23, "routine_id": 28, "branch_global_u8_4000": 1},
		],
		"setup_mmo_followup_write": {"offset": 0x022D, "bank": 0, "index": 1, "value": 7},
		"setup_terminal_status": "shared_routine_boundary",
		"setup_terminal_offset": 0x0C0E,
		"setup_terminal_message_count": 0,
		"exe_audit_schema": "kakyu_ai5_mes_exe_audit/v106",
	},
	"EVENTD14.MES": {
		"label": "Maki host-selected dialogue fragments",
		"source": CATALOG_SOURCED_ENTRY,
		"entry_count": 66,
		"caller_op": "script_dispatch",
		"setup_start_coordinate": 0,
		"setup_entry_offset": 0x0008,
		"setup_entry_index": 0,
		"setup_start_kind": "audited_nested_call",
		"setup_reaches_event_choice": true,
		"nested_start_coordinate": 0,
		"bootstrap_command": 0x14,
		"bootstrap_op": "bootstrap_transfer",
		"bootstrap_target": 0x0008,
		"bootstrap_entry_index": 0,
		"setup_shared_routine": 28,
		"setup_shared_offset": 0x014D,
		"setup_shared_resume": 0x0152,
		"setup_native_offset": 0x016C,
		"setup_native_resume": 0x0177,
		"setup_native_record_count": 3,
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
			{
				"offset": 0x0DE9,
				"resume": 0x0DEE,
				"definition_id": 22,
				"source": "DEF_MAIN.MES:0x1102",
				"body_offset": 0x1109,
				"end_offset": 0x116E,
			},
			{
				"offset": 0x1396,
				"resume": 0x139B,
				"definition_id": 22,
				"source": "DEF_MAIN.MES:0x1102",
				"body_offset": 0x1109,
				"end_offset": 0x116E,
			},
			{
				"offset": 0x1476,
				"resume": 0x147B,
				"definition_id": 21,
				"source": "DEF_MAIN.MES:0x10BD",
				"body_offset": 0x10C4,
				"end_offset": 0x1102,
			},
			{
				"offset": 0x1878,
				"resume": 0x187D,
				"definition_id": 22,
				"source": "DEF_MAIN.MES:0x1102",
				"body_offset": 0x1109,
				"end_offset": 0x116E,
			},
			{
				"offset": 0x20DF,
				"resume": 0x20E4,
				"definition_id": 22,
				"source": "DEF_MAIN.MES:0x1102",
				"body_offset": 0x1109,
				"end_offset": 0x116E,
			},
			{
				"offset": 0x23AC,
				"resume": 0x23B1,
				"definition_id": 22,
				"source": "DEF_MAIN.MES:0x1102",
				"body_offset": 0x1109,
				"end_offset": 0x116E,
			},
			{
				"offset": 0x254E,
				"resume": 0x2553,
				"definition_id": 22,
				"source": "DEF_MAIN.MES:0x1102",
				"body_offset": 0x1109,
				"end_offset": 0x116E,
			},
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
		"route_completion_state_index": EVENTD14_COMPLETION_STATE_INDEX,
		"setup_terminal_status": "def_selection_boundary",
		"setup_terminal_offset": EVENTD14_CHOICE_BOUNDARY,
		"exe_audit_schema": "kakyu_ai5_mes_exe_audit/v106",
	},
}


var document: Dictionary = {}
var selected_entry := ""
var library_index: Dictionary = {}
var library_document: Dictionary = {}
var state: KakyuMesSandboxState = null
var runner: KakyuMesEventRunner = null
var preview_event_session := ""
var preview_definitions: Array[Dictionary] = []
var event_catalog: KakyuEventCatalog = null
var catalog_playback_request: Dictionary = {}
var startup_context: Dictionary = {}
var reader: KakyuArcReader = null
var resolver: KakyuContentResolver = null
var content_set: KakyuContentSet = null
var parser: KakyuMesContainer = null


func catalog_source_entry_sha256(entry: String) -> String:
	# The hash of a shared original entry the catalog records as a required
	# entry. The player froze eleven of these — the shared library, DEF_MAIN,
	# both picture scripts, the standing and expression layers, the expression
	# animation and the character BGM — where no catalog revision could reach
	# them.
	return str(event_catalog.find_source_entry(entry).get("entry_sha256", ""))


func is_catalog_source_entry(entry_sha256: String, entry: String) -> bool:
	# Fails closed when the catalog is unavailable: an absent hash matches
	# nothing, where an absent constant would have matched an absent hash.
	var expected := catalog_source_entry_sha256(entry)
	return not expected.is_empty() and entry_sha256 == expected


func indexed_routine_boundary(routine_id: int, panel_role: String) -> Dictionary:
	if routine_id < 0 or library_index.is_empty():
		return {}
	var routine: Dictionary = library_index.get("by_id", {}).get(routine_id, {})
	if routine.is_empty():
		return {}
	return {
		"routine_id": routine_id,
		"body_offset": int(routine.body_offset),
		"end_offset": int(routine.end_offset),
		"source": str(library_index.get("source", "resolved content")),
		"panel_role": panel_role,
	}


func has_authoritative_def26_registry_audit() -> bool:
	return (
		reader.is_open()
		and reader.get_archive_identity_fingerprint() == AUDITED_MES_ARCHIVE_SHA256
		and str(library_index.get("source", "")) == "original_arc"
		and str(startup_context.get("schema", "")) == ContentCoreVersionScript.MES_STARTUP_CONTEXT_SCHEMA
		and str(startup_context.get("source", "")) == "original_arc"
		and startup_context.get("selector_order", []) == AUDITED_STARTUP_CONTEXT_SELECTORS
	)


func audited_startup_registered_definitions() -> Dictionary:
	if not has_authoritative_def26_registry_audit():
		return {}
	var registered_definitions: Dictionary = startup_context.get("registered_definitions", {})
	if registered_definitions.size() != AUDITED_STARTUP_CONTEXT_SELECTORS.size():
		return {}
	return registered_definitions.duplicate(false)


func confirmed_address_catalog(entry_name: String, entry_sha256: String) -> Dictionary:
	var normalized_entry := entry_name.to_upper()
	var definition: Dictionary = CONFIRMED_ADDRESS_CATALOGS.get(normalized_entry, {})
	if definition.is_empty():
		return {}
	var resolved := definition.duplicate(true)
	if str(definition.get("source", "")) == CATALOG_SOURCED_ENTRY:
		var callee := event_catalog.find_callee_source(normalized_entry)
		var caller := event_catalog.find_caller_source(normalized_entry)
		if callee.is_empty() or caller.is_empty():
			return {}
		resolved["entry_sha256"] = str(callee.entry_sha256)
		# The caller envelope this catalog is reached through is catalog data too:
		# its entry, hash, dispatch and resume coordinates and dispatch command.
		resolved["caller_entry"] = str(caller.entry)
		resolved["caller_sha256"] = str(caller.entry_sha256)
		resolved["caller_offset"] = int(caller.dispatch_offset)
		resolved["caller_resume"] = int(caller.resume_offset)
		resolved["caller_command"] = int(caller.command)
	if str(resolved.get("entry_sha256", "")) != entry_sha256.to_lower():
		return {}
	return resolved


func catalog_setup_definition_resume(result: Dictionary) -> Dictionary:
	var definition := confirmed_address_catalog(selected_entry, str(document.get("entry_sha256", "")))
	if (
		preview_event_session != "catalog_setup"
		or definition.is_empty()
		or str(result.get("status", "")) != "definition_invoke_boundary"
	):
		return {}
	var trace: Array = result.get("trace", [])
	if trace.is_empty():
		return {}
	var record: Dictionary = trace[-1]
	for untyped_call in definition.get("setup_definition_calls", []):
		var call: Dictionary = untyped_call
		var registered: Dictionary = audited_startup_registered_definitions().get(int(call.definition_id), {})
		if (
			int(result.get("offset", -1)) == int(call.offset)
			and int(result.get("resume_offset", -1)) == int(call.resume)
			and int(record.get("source_offset", -1)) == int(call.offset)
			and int(record.get("definition_id", -1)) == int(call.definition_id)
			and int(registered.get("body_offset", -1)) == int(call.body_offset)
			and int(registered.get("end_offset", -1)) == int(call.end_offset)
			and str(registered.get("source", "")) == str(call.source)
		):
			return call.duplicate(true)
	return {}


