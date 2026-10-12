class_name KakyuPlaybackPackageExport
extends RefCounted

# Playback package exporter: step 2 of the modding tools repository split.
#
# The tools read the authoritative archives; the remake reads only a playback
# package. This tool produces one package for one catalog event, so the
# boundary fixed by docs/spec/tech/playback_package_schema.md can be built and
# measured before either repository is cut.
#
# Membership, fingerprints, presets, choices, and terminals come from the
# tracked event catalog, not from this tool. Records come from the authoritative
# archive through the same Content Core container and analysis path the runner
# uses.
#
# The projection is fail-closed: every operand type and every operand field is
# either kept by an explicit rule or dropped by an explicit rule. An
# unclassified type or field aborts the export instead of silently leaving the
# package short.
#
# The package carries original dialogue. Write it only to an untracked
# directory. This tool never prints message text.

const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesLibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const DecoderScript := preload("res://content_core/mes_instruction_decoder.gd")
const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const Cp932CodecScript := preload("res://content_core/cp932_codec.gd")
const ContentCoreVersionScript := preload("res://content_core/content_core_version.gd")
const PackageIntegrityScript := preload("res://content_core/playback_package_integrity.gd")
const PackageScript := preload("res://content_core/playback_package.gd")
const PublicationLockScript := preload("res://content_core/publication_lock.gd")
const ContractValuesScript := preload("res://content_core/contract_values.gd")
const ArchiveIdentityScript := preload("res://content_core/original_archive_identity.gd")
const MediaClassifierScript := preload("res://content_core/playback_media_classifier.gd")
const InventoryScript := preload("res://content_core/playback_package_inventory.gd")
const MediaIdentityScript := preload("res://tools/content_suite/playback_media_identity.gd")

const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"
const ARCHIVE_SHA256 := ArchiveIdentityScript.MES_ARC_SHA256
const DEFAULT_EVENT_ID := "original/eventb03/01m-0000788f"
const ANALYSIS_GROUPS_DIR := "res://config/event_catalog/analysis_groups"
const MEMBERSHIP_RULE_FULL := "catalog_events_and_analysis_group_members"
const MEMBERSHIP_RULE_SELECTED := "selected_catalog_events"
const ROLE_ANALYSIS_GROUP_MEMBER := "analysis_group_member"

# Source line markers, entry labels, and record separators. Measured at 26% of
# event-corpus instructions with no playback effect; see the schema document.
#
# The exception is an instance that opens a bounded native stream. The runner
# skips such a stream from the instruction that introduces it, so dropping that
# instance would lose the skip and land playback inside the stream payload. Such
# a record is kept; _is_provenance decides.
const PROVENANCE_COMMANDS := {0x1F: true, 0x17: true, 0xFF: true}

# Instruction fields mes_event_runner.gd reads, minus the ones that only exist
# to describe bytes. Anything else on an instruction is analysis provenance.
const INSTRUCTION_FIELD_MAP := {
	"script_target": "script_target",
	"native_handler_family": "family",
	"native_stream_consumption": "stream",
	"system_function": "system_function",
	"native_record_consumption": "record_consumption",
	"native_record_count": "record_count",
	"native_record_terminator_consumed": "record_terminator",
	"structural_only": "structural_only",
}
const DROPPED_INSTRUCTION_KEYS := {
	"ok": true,
	"schema": true,
	"op": true,
	"command_id": true,
	"source_offset": true,
	"end_offset": true,
	"byte_length": true,
	"raw_hex": true,
	"operands": true,
	"region": true,
	"native_stream_probe": true,
	"native_stream_projection_match": true,
}

# Operand fields kept for the typed presentation and native operands. These
# select what to play; the dropped remainder describes the original
# executable dispatch and is not a playback input.
const TYPED_OPERAND_KEEP := {
	"presentation_subcommand": true,
	"execution_selector": true,
	"selector_source": true,
	"mode": true,
	"record_count": true,
	"consumer_index": true,
	"consumer_virtual_slot": true,
	"cell_row": true,
	"cell_column": true,
	"data_archive_index": true,
	"argument_count": true,
	"resource_kind": true,
	"name": true,
	"source_name": true,
	"queue_selector": true,
	"playback_selector": true,
	"source_x": true,
	"source_y": true,
	"inclusive_right": true,
	"inclusive_bottom": true,
	"source_surface_index": true,
	"destination_x": true,
	"destination_y": true,
	"destination_surface_index": true,
	"inclusive_left": true,
	"inclusive_top": true,
	"refresh_origin_default": true,
	"literal_mode": true,
	"resource_archive": true,
	# Kept because mes_event_runner.gd copies them into the trace at the
	# inline-script-execution and native-state-transfer boundaries (START.MES,
	# 43C.MES); `mappings` is the decoded form of `mapping_string` (an array
	# of small dictionaries of ints and strings).
	"execution_role": true,
	"transfer_selector": true,
	"snapshot_selector": true,
	"mapping_string": true,
	"mappings": true,
}

# Dropped even though the names carry no native_ prefix. Two groups: the
# original consumer-table geometry, which the remake's own AX and surface
# components already own as constants, and byte-level provenance about which
# outer command carried a marker.
const DROPPED_TYPED_OPERAND_KEYS := {
	"consumer_vector_offset": true,
	"cell_rows": true,
	"cell_columns": true,
	"cell_record_bytes": true,
	"cell_state_offset": true,
	"cell_state_value": true,
	"cell_update_flag_offset": true,
	"cell_update_flag_value": true,
	"inactive_state": true,
	"binding_table_entries": true,
	"binding_table_entry_bytes": true,
	"binding_table_bytes": true,
	"binding_offsets": true,
	"consumer_table_rows": true,
	"consumer_table_columns": true,
	"consumer_cell_bytes": true,
	"buffer_argument": true,
	"outer_command": true,
	"outer_command_source_offset": true,
}
const TYPED_OPERAND_EXPRESSION_KEYS := {
	"channel_expression": true,
	"expression": true,
	"index_expression": true,
	"value_expression": true,
}
const TYPED_OPERAND_EXPRESSION_LIST_KEYS := {"expressions": true}

# Dropped by name, in addition to the native_/tool_/_semantics rules.
const DROPPED_OPERAND_KEYS := {
	"type": true,
	"ok": true,
	"schema": true,
	"offset": true,
	"end_offset": true,
	"byte_length": true,
	"raw_hex": true,
	"raw_bytes": true,
	"source_offset": true,
	"source": true,
	"region": true,
	"gameplay_state_effect": true,
}

var _cp932 := Cp932CodecScript.new()
var _decoder := DecoderScript.new()
var _dropped_instruction_keys: Dictionary = {}
var _dropped_operand_keys: Dictionary = {}
var _unclassified_operand_keys: Dictionary = {}
var _unclassified_operand_types: Dictionary = {}
var _failures: Array[String] = []
var _text_strings: Array[String] = []
var _text_index: Dictionary = {}
var _undecodable_text_count := 0
var _unresolved_expression_count := 0
var _text_round_trip_failures := 0
var _resource_names: Dictionary = {}
var _active_text_projection: Dictionary = {}
var _used_text_offsets: Dictionary = {}
var _projecting_offset := -1


# Builds one package for one or more catalog events. Passing an empty id list
# takes every event the catalog declares, which is the shape the split plan
# wants: the shared library and the registered definitions are members once,
# not once per event.
# Merges every analysis-group profile's source_members into catalog_members.
# catalog_members keeps its original order and gets bound_by: [] on every
# entry; new members (analysis-group-only entries) are appended in the order
# they are first seen, sorted profile files each read in file order.
#
# When `events` is given (a selected, non-full build), the merge is scoped to
# only the profiles those events' own `analysis_group.groups[]` reference -
# every EP-10 catalog row's required_entries already carries
# `role: "analysis_group_member"` for its route's shared members, but a
# selected build has no use for an unrelated event's group (and no
# entitlement to fail on that group's own file problems). A full build passes
# every catalog event, so every tracked profile is referenced by construction
# and this scoping changes nothing for it. `events` empty (the default) keeps
# the unrestricted directory scan the direct callers below use.
func analysis_group_members(directory: String, catalog_members: Array[Dictionary], events: Array[Dictionary] = []) -> Dictionary:
	var integrity := PackageIntegrityScript.new()
	var failures: Array[String] = []
	var members: Array[Dictionary] = []
	var index: Dictionary = {}
	var origin: Dictionary = {}
	var restrict := not events.is_empty()
	var referenced_hashes: Dictionary = {}
	if restrict:
		for untyped_event in events:
			var event: Dictionary = untyped_event
			for group_ref_value in event.get("analysis_group", {}).get("groups", []):
				referenced_hashes[str((group_ref_value as Dictionary).get("profile_sha256", ""))] = true
	for untyped_member in catalog_members:
		var member: Dictionary = (untyped_member as Dictionary).duplicate(true)
		member["bound_by"] = []
		var entry_key := str(member.entry)
		index[entry_key] = members.size()
		origin[entry_key] = "the event catalog"
		members.append(member)

	var dir := DirAccess.open(directory)
	if dir == null:
		return {"ok": false, "failures": ["analysis group directory %s could not be opened" % directory], "members": members, "groups": []}
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.get_extension().to_lower() == "json":
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()

	# Profile identity is the file stem, not group_id: a group is versioned by
	# committing a new file (e.g. _v1, _v2), and both versions can stay
	# legitimately committed at once. group_id may therefore repeat across
	# files; payload_sha256 must not, since two files with the same payload
	# hash would be the same measurement recorded twice.
	var payload_hashes: Dictionary = {}
	var groups: Array[Dictionary] = []
	for file_name in names:
		var profile_stem := file_name.get_basename()
		var path := directory.path_join(file_name)
		var handle := FileAccess.open(path, FileAccess.READ)
		if handle == null:
			failures.append("analysis group %s: could not be opened" % file_name)
			continue
		var text := handle.get_as_text()
		handle.close()
		var parsed: Variant = JSON.parse_string(text)
		if not parsed is Dictionary:
			failures.append("analysis group %s: is not a JSON object" % file_name)
			continue
		var profile: Dictionary = parsed
		if restrict and not referenced_hashes.has(str(profile.get("payload_sha256", ""))):
			continue
		var group_id: Variant = profile.get("group_id")
		if not group_id is String or (group_id as String).is_empty():
			failures.append("analysis group %s: group_id must be a non-empty string" % file_name)
			continue
		var schema: Variant = profile.get("schema")
		if not schema is String or (schema as String).is_empty():
			failures.append("analysis group %s: schema must be a non-empty string" % file_name)
			continue
		var payload_sha256: Variant = profile.get("payload_sha256")
		if not integrity.is_sha256(payload_sha256):
			failures.append("analysis group %s: payload_sha256 must be a 64-hex string" % file_name)
			continue
		var source_members: Variant = profile.get("source_members")
		if not source_members is Array or (source_members as Array).is_empty():
			failures.append("analysis group %s: source_members must be a non-empty array" % file_name)
			continue
		var member_rows: Array[Dictionary] = []
		var member_problem := false
		for untyped_row in (source_members as Array):
			if not untyped_row is Dictionary:
				failures.append("analysis group %s: source_members entry must be an object" % file_name)
				member_problem = true
				break
			var row: Dictionary = untyped_row
			if not integrity.safe_entry(row.get("entry")):
				failures.append("analysis group %s: source_members entry name is invalid" % file_name)
				member_problem = true
				break
			if not integrity.is_sha256(row.get("entry_sha256")):
				failures.append("analysis group %s: source_members entry_sha256 is invalid" % file_name)
				member_problem = true
				break
			member_rows.append({"entry": str(row.entry), "entry_sha256": str(row.entry_sha256)})
		if member_problem:
			continue
		if payload_hashes.has(payload_sha256):
			failures.append("analysis group %s: payload_sha256 duplicates %s" % [file_name, str(payload_hashes[payload_sha256])])
			continue
		payload_hashes[payload_sha256] = file_name
		groups.append({"profile": profile_stem, "group_id": group_id, "schema": schema, "payload_sha256": payload_sha256})
		for row in member_rows:
			var entry: String = row.entry
			if index.has(entry):
				var existing: Dictionary = members[index[entry]]
				if str(existing.entry_sha256) != row.entry_sha256:
					failures.append("%s: membership fingerprint conflict between %s and analysis group %s" % [entry, str(origin[entry]), profile_stem])
					continue
				var bound_by: Array = existing.bound_by
				if not bound_by.has(profile_stem):
					bound_by.append(profile_stem)
			else:
				var new_member := {"entry": entry, "entry_sha256": row.entry_sha256, "role": ROLE_ANALYSIS_GROUP_MEMBER, "bound_by": [profile_stem]}
				index[entry] = members.size()
				origin[entry] = "analysis group %s" % profile_stem
				members.append(new_member)

	for member in members:
		var bound_by: Array = member.bound_by
		bound_by.sort()
	groups.sort_custom(func(a, b): return str(a.profile) < str(b.profile))
	return {"ok": failures.is_empty(), "failures": failures, "members": members, "groups": groups}


func select_event_ids(catalog: KakyuEventCatalog, event_ids: Array) -> Array[String]:
	# The rows a build actually packages. An explicit id list is used as
	# given. EP-10 unit 5b/c: every catalog row is now EP-10 generated (each
	# carries `analysis_group`), so an empty list (a full build) selects
	# every one of them.
	var selected: Array[String] = []
	for untyped_id in event_ids:
		selected.append(str(untyped_id))
	if selected.is_empty():
		for untyped_event in catalog.get_events():
			var candidate: Dictionary = untyped_event
			selected.append(str(candidate.event_id))
	return selected


func build(source_root: String, event_ids: Array, options: Dictionary = {}) -> Dictionary:
	var catalog := EventCatalogScript.new()
	var loaded := catalog.load_file(CATALOG_PATH)
	if not loaded.get("ok", false):
		return _build_failure("Event catalog: %s" % str(loaded.get("error", "load failed")))
	var selected: Array[String] = select_event_ids(catalog, event_ids)
	var events: Array[Dictionary] = []
	for event_id in selected:
		var event: Dictionary = catalog.get_event(event_id)
		if event.is_empty():
			return _build_failure("Event catalog has no event %s." % event_id)
		events.append(event)

	var reader := ArcReaderScript.new()
	if not reader.open(source_root + "/mes.arc"):
		return _build_failure(str(reader.last_error))
	if reader.get_archive_fingerprint() != ARCHIVE_SHA256:
		reader.close()
		return _build_failure("Authoritative mes.arc fingerprint changed.")

	var catalog_members := EventCatalogScript.source_members_for_events(events)
	# EP-10 unit 5bc, part 4: every catalog row now carries
	# `role: "analysis_group_member"` on its own required_entries, so a
	# selected (non-full) build needs its own events' groups merged in too -
	# to bind those entries' `bound_by` and to add their caller entry, which
	# `source_members_for_events` never carries. Default is therefore always
	# on; `{"analysis_groups": false}` remains an explicit opt-out.
	var include_groups: bool = options.get("analysis_groups", true)
	var groups_dir: String = str(options.get("analysis_groups_directory", ANALYSIS_GROUPS_DIR))
	# EP-12 PROMIS checkpoint C (2026-09-25): a scratch, explicitly opt-in
	# bootstrap for a brand-new ordinary site's own v6 projection, which
	# needs its own callee's exported member entries before any catalog row
	# can reference it (project_event_definition_v6.py's ordinary path reads
	# every involved entry from the package). Unused by every existing
	# caller (default false, and `analysis_group_members`'s own restriction
	# is otherwise unchanged), so a plain export stays byte for byte what it
	# was: `catalog_members` still reflects the real selected events, only
	# the *group-membership* restriction is lifted, exactly as an empty
	# `events` argument already does for `analysis_group_members`'s own
	# unrestricted directory scan.
	var include_unbound_groups: bool = options.get("include_unbound_groups", false)
	var members: Array[Dictionary] = []
	var analysis_groups: Array[Dictionary] = []
	if include_groups:
		var empty_events: Array[Dictionary] = []
		var merged := analysis_group_members(groups_dir, catalog_members, empty_events if include_unbound_groups else events)
		if not merged.get("ok", false):
			reader.close()
			return _build_failure("; ".join(PackedStringArray(merged.get("failures", []))))
		members = merged.members
		analysis_groups = merged.groups
	else:
		for untyped_member in catalog_members:
			var member: Dictionary = (untyped_member as Dictionary).duplicate(true)
			member["bound_by"] = []
			members.append(member)
	var parser := MesContainerScript.new()
	var analysis_builder := MesAnalysisScript.new()
	var entry_reports: Array[Dictionary] = []
	# TD-64 part 2: each member is serialized and fed to the two accumulators as
	# soon as it is built, and its documents are dropped with the loop's next turn.
	# The build holds the payloads (the package's bytes) and the accumulators'
	# results, never all 869 documents as Variants.
	var payloads: Dictionary = {}
	var member_names: Array = []
	for untyped_member in members:
		member_names.append(str((untyped_member as Dictionary).entry))
	var inventory = InventoryScript.new().begin(member_names)
	var media_accumulator = MediaIdentityScript.new().begin(source_root)

	for untyped_member in members:
		var member: Dictionary = untyped_member
		var entry_name := str(member.entry)
		var payload := _read_payload(reader, entry_name)
		if payload.is_empty():
			_failures.append("%s: entry is missing from mes.arc" % entry_name)
			continue
		var document := parser.parse(payload, {"entry": entry_name})
		if not document.get("ok", false):
			_failures.append("%s container: %s" % [entry_name, str(document.get("error", "failed"))])
			continue
		var entry_sha256 := str(document.get("entry_sha256", ""))
		if reader.get_entry_fingerprint(entry_name) != str(member.entry_sha256):
			_failures.append("%s: catalog fingerprint does not match the archive entry" % entry_name)
			continue
		_active_text_projection = _text_projection(entry_name)
		_used_text_offsets.clear()
		var exported: Dictionary
		var scan_references: Array[Dictionary] = []
		if entry_name.get_extension().to_lower() == "lib":
			# A library is a zero-entry-table container: its executable code is
			# the registered routine bodies, not an entry region. The plain
			# analysis path decodes only its bootstrap and leaves the rest an
			# opaque tail, so the library index owns this membership.
			exported = _export_library_entry(entry_name, entry_sha256, str(member.role), document)
			# The whole-code resource scan, with the labels `build_structural`
			# gives it: nothing but the bootstrap is decoded, so every hit it
			# finds in a routine is a bounded envelope hit.
			var library_scan := analysis_builder.build_structural(document)
			if not library_scan.get("ok", false):
				_failures.append("%s resource scan: %s" % [entry_name, str(library_scan.get("error", "failed"))])
				continue
			scan_references = _scan_references(library_scan)
		else:
			# Structural decoding, because mes_event_runner.gd decodes with
			# decode_at_structural. Strict analysis is the decompiler's path and
			# leaves large boundary-only expression regions opaque.
			var analysis := analysis_builder.build_structural(document)
			if not analysis.get("ok", false):
				_failures.append("%s analysis: %s" % [entry_name, str(analysis.get("error", "failed"))])
				continue
			exported = _export_entry(entry_name, entry_sha256, str(member.role), document, analysis)
			scan_references = _scan_references(analysis)
		if exported.is_empty():
			continue
		exported.report["bound_by"] = member.get("bound_by", [])
		if _used_text_offsets.size() != _active_text_projection.size():
			_failures.append("%s has a text edit outside the exported message boundaries" % entry_name)
		payloads[entry_name] = _stream_member(entry_name, exported.document, exported.text_document, inventory)
		media_accumulator.add(entry_name, exported.document, exported.text_document.strings, scan_references)
		entry_reports.append(exported.report)
	reader.close()

	if entry_reports.is_empty():
		_failures.append("the selected events declare no mes.arc member entry")
	var stems: Dictionary = {}
	for untyped_report in entry_reports:
		var stem := _entry_stem(str((untyped_report as Dictionary).entry))
		if stems.has(stem):
			_failures.append("two member entries share the document name %s" % stem)
		stems[stem] = true
	if not _unclassified_operand_types.is_empty():
		_failures.append(
			"unclassified operand types: %s" % JSON.stringify(_unclassified_operand_types.keys())
		)
	if not _unclassified_operand_keys.is_empty():
		_failures.append(
			"unclassified operand fields: %s" % JSON.stringify(_unclassified_operand_keys.keys())
		)
	# WD-21 U1: the media inventory's evidence. The occurrences are classified
	# from the package's own records and cross-checked against the analysis scan
	# (a strict scan hit that is no record fails the build), and every referenced
	# name is looked up in the original archives the source root holds. Both
	# accumulators were fed per member above.
	var media_inventory: Dictionary = {}
	var inventory_evidence: Dictionary = {}
	if _failures.is_empty():
		media_inventory = media_accumulator.finish()
		if not media_inventory.get("ok", false):
			for failure in media_inventory.get("failures", []):
				_failures.append(str(failure))
		inventory_evidence = inventory.finish()
		if inventory_evidence.has("error"):
			_failures.append(str(inventory_evidence.error))
	var after := ArcReaderScript.new()
	if not after.open(source_root + "/mes.arc") or after.get_archive_fingerprint() != ARCHIVE_SHA256:
		_failures.append("mes.arc fingerprint changed during the export")
	after.close()
	if not _failures.is_empty():
		return {"ok": false, "failures": _failures.duplicate()}
	var catalog_member_count := 0
	var analysis_group_member_count := 0
	for untyped_member in members:
		if str((untyped_member as Dictionary).get("role", "")) == ROLE_ANALYSIS_GROUP_MEMBER:
			analysis_group_member_count += 1
		else:
			catalog_member_count += 1
	# The load result carries the catalog's identity, not its document, so the
	# manifest binding is taken from the two fields `validate` guarantees
	# (a slug id and a positive revision). `serialize` refuses anything else.
	# The referenced resource names travel in the build result, so a
	# serialization never depends on which exporter instance built it.
	var resource_names: Array = _resource_names.keys()
	resource_names.sort()
	return {
		"ok": true,
		"events": events,
		"catalog": {
			"catalog_id": loaded.get("catalog_id", ""),
			"catalog_revision": loaded.get("catalog_revision", 0),
		},
		"resource_names": resource_names,
		"media_identity": media_inventory.media_identity,
		"media_scan": media_inventory.media_scan,
		"media": _media_entries(events),
		"entry_reports": entry_reports,
		"payloads": payloads,
		"inventory_evidence": inventory_evidence,
		"dropped_instruction_fields": _dropped_instruction_keys.duplicate(),
		"dropped_operand_fields": _dropped_operand_keys.duplicate(),
		"undecodable_text_payloads": _undecodable_text_count,
		"unresolved_expression_boundaries": _unresolved_expression_count,
		"text_round_trip_failures": _text_round_trip_failures,
		"membership": {
			"rule": MEMBERSHIP_RULE_FULL if event_ids.is_empty() else MEMBERSHIP_RULE_SELECTED,
			"catalog_events": events.size(),
			"catalog_members": catalog_member_count,
			"analysis_group_members": analysis_group_member_count,
			"analysis_groups": analysis_groups,
		},
	}


func _read_payload(reader: KakyuArcReader, entry: String) -> PackedByteArray:
	return reader.read_entry(entry)


# One member of a build, streamed (TD-64 part 2): both of its package files are
# serialized and fingerprinted at once, and its document and strings are fed to
# the inventory accumulator. This is the only place a member's payloads are made,
# for `build()` and for `payloads_for()` alike.
func _stream_member(entry_name: String, document: Dictionary, text_document: Dictionary, inventory) -> Dictionary:
	inventory.add(entry_name, document, text_document.get("strings", []))
	var stem := _entry_stem(entry_name)
	return {
		"events": _payload("events/%s.json" % stem, document),
		"text": _payload("text/%s.json" % stem, text_document),
	}


# The payloads and the inventory evidence of documents already in hand: the
# members of a build result that was not made by `build()`. It runs the
# per-entry function `build()` runs, so a fixture cannot make a build result
# `build()` could not. `documents` and `texts` map each member entry to its
# events document and its text document. Returns `{payloads,
# inventory_evidence}`, the two keys `serialize()` reads in place of documents.
func payloads_for(documents: Dictionary, texts: Dictionary) -> Dictionary:
	var names: Array = documents.keys()
	var inventory = InventoryScript.new().begin(names)
	var payloads := {}
	for entry_name in names:
		payloads[entry_name] = _stream_member(str(entry_name), documents[entry_name], texts.get(entry_name, {}), inventory)
	return {"payloads": payloads, "inventory_evidence": inventory.finish()}


# The analysis scan's resource references, reduced to what the media inventory
# cross-check compares: where, which kind, the normalized name and the scan's
# own boundary label.
func _scan_references(analysis: Dictionary) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for untyped_reference in analysis.get("resource_references", []):
		var reference: Dictionary = untyped_reference
		hits.append({
			"at": int(reference.source_offset),
			"kind": str(reference.resource_kind),
			"name": MediaClassifierScript.normalize_name(reference.name),
			"boundary": str(reference.boundary),
		})
	return hits


func _text_projection(_entry: String) -> Dictionary:
	return {}


# The manifest's `source.catalog_id` and `source.catalog_revision` name the
# catalog the events came from. The catalog itself accepts only a lowercase
# ASCII slug id and a positive revision, so a binding that is not one means the
# caller lost the load result; refuse it instead of writing an unbound package.
# The slug rule is the catalog's own (`KakyuEventCatalog.is_slug`).
func _catalog_binding_error(catalog: Variant) -> String:
	if not catalog is Dictionary:
		return "Package catalog binding is missing or not an object."
	var catalog_id: Variant = catalog.get("catalog_id", null)
	if typeof(catalog_id) != TYPE_STRING or not EventCatalogScript.is_slug(catalog_id):
		return "Package catalog binding has no catalog_id slug."
	var revision: Variant = catalog.get("catalog_revision", null)
	if not ContractValuesScript.json_integer(revision) or int(revision) <= 0:
		return "Package catalog binding has no positive catalog_revision."
	return ""


func serialize(built: Dictionary) -> Dictionary:
	if not built.get("ok", false):
		return {"ok": false, "failures": built.get("failures", [])}
	var binding_problem := _catalog_binding_error(built.get("catalog", null))
	if not binding_problem.is_empty():
		return {"ok": false, "failures": [binding_problem]}
	if not built.get("resource_names", null) is Array:
		return {"ok": false, "failures": ["Build result does not carry the referenced resource names."]}
	# TD-64 part 2: the members were serialized as they were built, so this
	# consumes their payloads and the inventory accumulator's result and never a
	# document. A payload dictionary is copied shallowly; its bytes are shared.
	var files: Array[Dictionary] = []
	var payloads: Variant = built.get("payloads", null)
	if not payloads is Dictionary:
		return {"ok": false, "failures": ["Build result does not carry the member payloads."]}
	for entry_name in (payloads as Dictionary).keys():
		var pair: Variant = payloads[entry_name]
		if not pair is Dictionary or not pair.get("events") is Dictionary or not pair.get("text") is Dictionary:
			return {"ok": false, "failures": ["%s member payloads are malformed" % str(entry_name)]}
		files.append((pair.events as Dictionary).duplicate())
		files.append((pair.text as Dictionary).duplicate())
	for file in files:
		if not bool(file.get("ok", false)):
			return {"ok": false, "failures": ["%s could not be serialized" % str(file.get("name", ""))]}

	# WD-21 U1: the media inventory and script reference blocks, recomputed by
	# the reader from the same records, so a producer cannot write what its own
	# reader refuses.
	var evidence: Variant = built.get("inventory_evidence", null)
	if not evidence is Dictionary:
		return {"ok": false, "failures": ["Build result does not carry the package inventory evidence."]}
	var evidence_members: Variant = (evidence as Dictionary).get("member_set", null)
	if not evidence_members is Dictionary or (evidence_members as Dictionary).size() != built.entry_reports.size():
		return {"ok": false, "failures": ["Build result's inventory evidence does not cover its member entries."]}
	for untyped_report in built.entry_reports:
		if not (evidence_members as Dictionary).has(str((untyped_report as Dictionary).get("entry", ""))):
			return {"ok": false, "failures": ["Build result's inventory evidence does not cover its member entries."]}
	var inventory_blocks := InventoryScript.new().build_blocks_from(
		evidence, built.get("media_identity", null), built.get("media_scan", null)
	)
	if not inventory_blocks.get("ok", false):
		return {"ok": false, "failures": [str(inventory_blocks.get("error", "The media inventory could not be built."))]}
	var declared_media: Array[String] = []
	for untyped_media in built.media:
		var media_entry: Dictionary = untyped_media
		declared_media.append("%s:%s" % [str(media_entry.archive), str(media_entry.entry)])
	var referenced_names: Array = (built.resource_names as Array).duplicate()
	referenced_names.sort()
	var event_descriptors: Array[Dictionary] = []
	for untyped_event in built.events:
		var event: Dictionary = untyped_event
		var callee: Dictionary = event.get("source", {}).get("callee", {})
		event_descriptors.append({
			"event_id": str(event.event_id),
			"title": str(event.get("display", {}).get("title", "")),
			"playback_status": str(event.get("playback_status", "")),
			"entry": str(callee.get("entry", "")),
			"start_coordinate": int(callee.get("start_coordinate", 0)),
			"presets": event.get("presets", []),
			"choices": event.get("choices", []),
			"terminals": event.get("terminals", []),
		})
	var catalog_document: Dictionary = built.catalog
	var membership: Dictionary
	if built.has("membership"):
		membership = built.membership
	else:
		var catalog_count := 0
		var group_count := 0
		for untyped_report in built.entry_reports:
			if str((untyped_report as Dictionary).get("role", "")) == ROLE_ANALYSIS_GROUP_MEMBER:
				group_count += 1
			else:
				catalog_count += 1
		membership = {
			"rule": MEMBERSHIP_RULE_SELECTED,
			"catalog_events": built.events.size(),
			"catalog_members": catalog_count,
			"analysis_group_members": group_count,
			"analysis_groups": [],
		}
	var manifest := {
		"schema": ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		"content_core_version": ContentCoreVersionScript.CORE_VERSION,
		"source": {
			"archive": "mes.arc",
			"archive_sha256": ARCHIVE_SHA256,
			"catalog_id": str(catalog_document.get("catalog_id", "")),
			"catalog_revision": int(catalog_document.get("catalog_revision", 0)),
		},
		"workspace_binding": built.get("workspace_binding", {}),
		"events": event_descriptors,
		"entries": built.entry_reports,
		"media": {
			"extracted": false,
			"boundary": "script and text only; media extraction is a separate unit",
			"catalog_declared": declared_media,
			"referenced_resource_names": referenced_names,
		},
		"media_inventory": inventory_blocks.media_inventory,
		"script_references": inventory_blocks.script_references,
		"records": {
			"provenance_commands_dropped": ["0x1F", "0x17", "0xFF"],
			"dropped_instruction_fields": built.dropped_instruction_fields,
			"dropped_operand_fields": built.dropped_operand_fields,
			"undecodable_text_payloads": int(built.undecodable_text_payloads),
			"unresolved_expression_boundaries": int(built.unresolved_expression_boundaries),
			"text_round_trip_failures": int(built.text_round_trip_failures),
			"opaque_regions": "recorded as non-executable boundaries without bytes",
		},
		"membership": membership,
		"incompleteness": {
			"standalone_complete": false,
			"media_extraction": "deferred",
			"external_terminals": _external_terminals(event_descriptors, built.entry_reports),
		},
	}
	var integrity := PackageIntegrityScript.new()
	manifest = integrity.bind(manifest, files)
	var manifest_error := integrity.manifest_error(manifest)
	if not manifest_error.is_empty():
		return {"ok": false, "failures": [manifest_error]}
	var manifest_file := _payload("manifest.json", manifest)
	if not bool(manifest_file.get("ok", false)):
		return {"ok": false, "failures": ["manifest could not be serialized"]}
	files.append(manifest_file)
	return {"ok": true, "files": files, "manifest": manifest}


func write(output_root: String, serialized: Dictionary) -> Dictionary:
	var problem := _serialized_error(serialized)
	if not problem.is_empty():
		return _build_failure(problem)
	if output_root.strip_edges().is_empty():
		return _build_failure("Choose a new package output directory.")
	var root := ProjectSettings.globalize_path(_normalize_path(output_root)).simplify_path()
	if not root.is_absolute_path() or root.get_file().is_empty():
		return _build_failure("Package output must name an absolute directory.")
	var locks := PublicationLockScript.new()
	var lock := locks.acquire(root.get_base_dir(), ".%s.playback.lock" % root.get_file())
	if not lock.ok:
		return _build_failure(str(lock.error))
	var result := _write_locked(root, serialized)
	var released := locks.release(lock)
	if not released.ok:
		result["ok"] = false
		result["failures"] = result.get("failures", []) + [str(released.error)]
	return result


func _serialized_error(serialized: Dictionary) -> String:
	if not serialized.get("ok", false):
		var messages: Array[String] = []
		for failure in serialized.get("failures", []):
			messages.append(str(failure))
		return "; ".join(messages) if not messages.is_empty() else "A successfully serialized package is required."
	if not serialized.get("files") is Array or not serialized.get("manifest") is Dictionary:
		return "A successfully serialized package is required."
	var problem := PackageIntegrityScript.new().manifest_error(serialized.manifest)
	if not problem.is_empty():
		return problem
	var expected := {"manifest.json": {}}
	for file in serialized.manifest.files:
		expected[file.name] = file
	var seen := {}
	for file in serialized.files:
		if not file is Dictionary or not file.get("name") is String or not expected.has(file.name) or seen.has(file.name):
			return "Serialized package has an unexpected or duplicate file."
		if not file.get("payload") is PackedByteArray:
			return "Serialized package file payload is invalid."
		var digest := _sha256_bytes(file.payload)
		if file.get("sha256") != digest or file.get("size") != file.payload.size():
			return "Serialized package file changed after serialization."
		var binding: Dictionary = expected[file.name]
		if not binding.is_empty() and (binding.sha256 != digest or int(binding.size) != file.payload.size()):
			return "Serialized package file does not match its manifest."
		seen[file.name] = true
	return "" if seen.size() == expected.size() else "Serialized package file inventory is incomplete."


func _write_locked(root: String, serialized: Dictionary) -> Dictionary:
	if FileAccess.file_exists(root) or DirAccess.dir_exists_absolute(root):
		return _build_failure("Package output already exists; nothing was replaced. Choose a new directory.")
	var stage := "%s.stage-%s-%s" % [root, OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(stage) != OK:
		return _build_failure("Could not create package staging directory.")
	var problem := ""
	if not _prepare_output(stage):
		problem = "Could not prepare package staging directory."
	else:
		for file in serialized.files:
			problem = _write_payload(stage.path_join(str(file.name)), file.payload)
			if not problem.is_empty():
				break
	if problem.is_empty():
		var reopened := PackageScript.new().load_directory(stage)
		if not reopened.ok or reopened.get("package_sha256") != serialized.manifest.package_sha256:
			problem = "Staged package failed reopen verification: %s" % reopened.get("error", "package identity changed")
	if problem.is_empty() and (FileAccess.file_exists(root) or DirAccess.dir_exists_absolute(root)):
		problem = "Package output appeared before publication; it was preserved."
	if problem.is_empty():
		var renamed := DirAccess.rename_absolute(stage, root)
		if renamed == OK:
			return {"ok": true, "root": root, "published": true, "package_sha256": serialized.manifest.package_sha256}
		problem = "Could not publish the verified package (error %s)." % renamed
	_remove_stage(root, stage, serialized.files)
	return _build_failure(problem)


func _write_payload(path: String, payload: PackedByteArray) -> String:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return "%s could not be written." % path.get_file()
	handle.store_buffer(payload)
	handle.flush()
	var stored := handle.get_error()
	handle.close()
	if stored != OK or FileAccess.get_sha256(path) != _sha256_bytes(payload):
		return "%s failed stored-file verification." % path.get_file()
	return ""


func _remove_stage(root: String, stage: String, files: Array) -> void:
	# Only our new sibling staging directory and its validated inventory may be
	# removed. Never recursively follow arbitrary content or touch final output.
	assert(stage.get_base_dir() == root.get_base_dir() and stage.begins_with(root + ".stage-"))
	for file in files:
		DirAccess.remove_absolute(stage.path_join(str(file.name)))
	for group in ["events", "text"]:
		DirAccess.remove_absolute(stage.path_join(group))
	DirAccess.remove_absolute(stage)


func _build_failure(message: String) -> Dictionary:
	return {"ok": false, "failures": [message]}


func _payload(name: String, document: Dictionary) -> Dictionary:
	var bytes := JSON.stringify(document, "", false, true).to_utf8_buffer()
	# Reparsing here is the producer half of the fail-closed contract: what the
	# package reports is what a consumer can actually read back.
	if JSON.new().parse(bytes.get_string_from_utf8()) != OK:
		return {"ok": false, "name": name, "payload": bytes, "size": bytes.size(), "sha256": ""}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return {
		"ok": true,
		"name": name,
		"payload": bytes,
		"size": bytes.size(),
		"sha256": context.finish().hex_encode(),
	}



func _media_entries(events: Array[Dictionary]) -> Array[Dictionary]:
	var media: Array[Dictionary] = []
	var seen: Dictionary = {}
	for untyped_event in events:
		for untyped_required in (untyped_event as Dictionary).get("source", {}).get("required_entries", []):
			var required: Dictionary = untyped_required
			if str(required.get("archive", "")) == "mes.arc":
				continue
			var key := "%s:%s" % [str(required.get("archive", "")), str(required.entry)]
			if seen.has(key):
				continue
			seen[key] = true
			media.append({
				"archive": str(required.get("archive", "")),
				"entry": str(required.entry),
				"role": str(required.get("role", "")),
			})
	return media


# Terminals owned by an mes.arc entry the package does not carry. The event
# descriptors here already carry the serialized "event_id"/"terminals" shape;
# entry_reports names the members the package actually has.
func _external_terminals(event_descriptors: Array, entry_reports: Array) -> Array[Dictionary]:
	var known: Dictionary = {}
	for untyped_report in entry_reports:
		known[str((untyped_report as Dictionary).get("entry", ""))] = true
	var rows: Array[Dictionary] = []
	for untyped_event in event_descriptors:
		var event: Dictionary = untyped_event
		var event_id := str(event.get("event_id", ""))
		for untyped_terminal in event.get("terminals", []):
			var terminal: Dictionary = untyped_terminal
			var owner: Variant = terminal.get("owner_entry")
			if not owner is String or known.has(owner):
				continue
			rows.append({
				"event_id": event_id,
				"terminal_id": str(terminal.get("terminal_id", "")),
				"owner_entry": owner,
				"offset": int(terminal.get("offset", 0)),
			})
	rows.sort_custom(func(a, b):
		if a.event_id != b.event_id:
			return a.event_id < b.event_id
		if a.owner_entry != b.owner_entry:
			return a.owner_entry < b.owner_entry
		if a.offset != b.offset:
			return a.offset < b.offset
		return a.terminal_id < b.terminal_id)
	return rows


func _export_entry(
	entry_name: String,
	entry_sha256: String,
	role: String,
	document: Dictionary,
	analysis: Dictionary
) -> Dictionary:
	_text_strings = []
	_text_index = {}
	var code: PackedByteArray = document.bytecode
	var records: Array[Dictionary] = []
	var kept_offsets: Dictionary = {}
	var swept := {"instructions": 0, "provenance": 0, "opaque": 0, "provenance_records": []}
	var code_limit := int(document.get("header", {}).get("code_size", code.size()))
	for untyped_region in _container_regions(document):
		var region: Dictionary = untyped_region
		_sweep(code, records, kept_offsets, int(region.at), int(region.end), entry_name, swept)
	var provenance_dropped := int(swept.provenance)

	# A linear sweep only sees instruction starts a linear reader would reach.
	# Code entered by a jump can begin inside what the sweep read as one
	# instruction, so every control target is followed to a fixed point.
	var reached_count := _close_reachability(code, records, kept_offsets, 0, code_limit, entry_name, swept.provenance_records)
	records.sort_custom(func(a, b): return int(a.at) < int(b.at))
	for index in range(records.size()):
		kept_offsets[int(records[index].at)] = index

	var regions := _container_regions(document)

	var target_audit := _audit_targets(records, kept_offsets, code.size())
	var header: Dictionary = document.get("header", {})
	var code_size := int(header.get("code_size", code.size()))
	var address_table: Array[int] = []
	for untyped_offset in header.get("entry_offsets", []):
		address_table.append(int(untyped_offset))
	var entry_document := {
		"schema": ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		"entry": entry_name,
		"provenance_records": swept.provenance_records,
		"entry_sha256": entry_sha256,
		"code_size": code_size,
		"code_sha256": _sha256_bytes(code.slice(0, code_size)),
		"address_table": address_table,
		"regions": regions,
		"records": records,
	}
	var text_document := {
		"schema": ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		"entry": entry_name,
		"encoding": "utf-8",
		"strings": _text_strings.duplicate(),
	}
	var report := {
		"entry": entry_name,
		"entry_sha256": entry_sha256,
		"role": role,
		"bytecode_bytes": code.size(),
		"instruction_count": int(swept.instructions) + reached_count,
		"record_count": records.size(),
		"provenance_dropped": provenance_dropped,
		"reached_by_transfer": reached_count,
		"text_count": _text_strings.size(),
		"region_count": regions.size(),
		"opaque_region_count": int(swept.opaque),
		"control_targets": target_audit,
	}
	return {"document": entry_document, "text_document": text_document, "report": report}


func _export_library_entry(
	entry_name: String,
	entry_sha256: String,
	role: String,
	document: Dictionary
) -> Dictionary:
	_text_strings = []
	_text_index = {}
	var code: PackedByteArray = document.bytecode
	var code_size := int(document.get("header", {}).get("code_size", code.size()))
	var index := MesLibraryIndexScript.new().build(code, code_size)
	if not index.get("ok", false):
		_failures.append("%s library index: %s" % [entry_name, str(index.get("error", "failed"))])
		return {}
	var routines: Array[Dictionary] = []
	var kept_offsets: Dictionary = {}
	var all_records: Array[Dictionary] = []
	var instruction_count := 0
	var provenance_dropped := 0
	var opaque_count := 0
	var library_reached := 0
	for untyped_routine in index.get("routines", []):
		var routine: Dictionary = untyped_routine
		var body_start := int(routine.body_offset)
		var body_end := int(routine.end_offset)
		var records: Array[Dictionary] = []
		var routine_offsets: Dictionary = {}
		var swept := {"instructions": 0, "provenance": 0, "opaque": 0, "provenance_records": []}
		_sweep(code, records, routine_offsets, body_start, body_end, entry_name, swept)
		instruction_count += int(swept.instructions)
		provenance_dropped += int(swept.provenance)
		opaque_count += int(swept.opaque)
		var routine_reached: int = _close_reachability(
			code, records, routine_offsets, body_start, body_end, entry_name, swept.provenance_records
		)
		instruction_count += routine_reached
		library_reached += routine_reached
		records.sort_custom(func(a, b): return int(a.at) < int(b.at))
		routines.append({
			"routine_id": int(routine.routine_id),
			"at": body_start,
			"end": body_end,
			"records": records,
			"provenance_records": swept.provenance_records,
		})
		all_records.append_array(records)
	for record_index in range(all_records.size()):
		kept_offsets[int(all_records[record_index].at)] = record_index
	var target_audit := _audit_targets(all_records, kept_offsets, code.size())
	var entry_document := {
		"schema": ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		"entry": entry_name,
		"entry_sha256": entry_sha256,
		"kind": "library",
		"code_size": code_size,
		"code_sha256": _sha256_bytes(code.slice(0, code_size)),
		"routines": routines,
	}
	var text_document := {
		"schema": ContentCoreVersionScript.PLAYBACK_PACKAGE_SCHEMA,
		"entry": entry_name,
		"encoding": "utf-8",
		"strings": _text_strings.duplicate(),
	}
	var report := {
		"entry": entry_name,
		"entry_sha256": entry_sha256,
		"role": role,
		"kind": "library",
		"bytecode_bytes": code_size,
		"instruction_count": instruction_count,
		"record_count": all_records.size(),
		"provenance_dropped": provenance_dropped,
		"reached_by_transfer": library_reached,
		"text_count": _text_strings.size(),
		"region_count": routines.size(),
		"registration_records_dropped": int(index.get("registration_count", 0)),
		"opaque_region_count": opaque_count,
		"control_targets": target_audit,
	}
	return {"document": entry_document, "text_document": text_document, "report": report}



# Follows every control target that has no record of its own, decoding forward
# from it until the walk rejoins a record the sweep already produced. Returns
# how many records were added.


# A provenance command carries no playback effect unless it opens a bounded
# native stream: the runner continues after that stream, so the instruction that
# opens it decides where execution resumes and has to stay in the package.
func _is_provenance(instruction: Dictionary) -> bool:
	if not PROVENANCE_COMMANDS.has(int(instruction.command_id)):
		return false
	var probe: Dictionary = instruction.get("native_stream_probe", {})
	return int(probe.get("consumed_byte_count", 0)) <= 0

func _container_regions(document: Dictionary) -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	var bootstrap: Dictionary = document.get("bootstrap", {})
	if int(bootstrap.get("size", 0)) > 0:
		regions.append({
			"id": "bootstrap",
			"at": int(bootstrap.offset),
			"end": int(bootstrap.end_offset),
		})
	for untyped_region in document.get("entries", []):
		var region: Dictionary = untyped_region
		regions.append({
			"id": str(region.id),
			"index": int(region.index),
			"at": int(region.offset),
			"end": int(region.end_offset),
		})
	return regions


# Decodes one range with the aligned region decoder, which is the only decoder
# that stays in step with a bounded native stream, then corrects each record's
# end offset to what the runner sees. The two disagree by design: the region
# decoder reports a bounded stream as part of the instruction that introduces
# it, and the runner reports that instruction alone. The package must match the
# runner, because the runner is what plays it.
func _sweep(
	code: PackedByteArray,
	records: Array[Dictionary],
	kept_offsets: Dictionary,
	region_start: int,
	region_end: int,
	entry_name: String,
	counters: Dictionary
) -> void:
	var decoded := _decoder.decode_region_structural_aligned(code, region_start, region_end)
	for untyped_instruction in decoded.get("instructions", []):
		var instruction: Dictionary = untyped_instruction
		counters.instructions += 1
		if _is_provenance(instruction):
			counters.provenance += 1
			counters.provenance_records.append({"at": int(instruction.source_offset), "end": int(instruction.end_offset)})
			continue
		var record := _project_instruction(instruction, code, entry_name)
		var runner_view := _decoder.decode_at_structural(
			code, int(instruction.source_offset), region_end
		)
		if runner_view.get("ok", false):
			record["end"] = int(runner_view.end_offset)
		records.append(record)
		kept_offsets[int(record.at)] = true
	if decoded.get("ok", false):
		return
	var stopped := int(decoded.get("decoded_end_offset", region_start))
	counters.opaque += 1
	records.append({
		"op": "opaque_region",
		"id": -1,
		"at": stopped,
		"end": region_end,
		"bytes": region_end - stopped,
		"reason": str(decoded.get("error", "region does not decode")),
	})
	kept_offsets[stopped] = true

func _close_reachability(
	code: PackedByteArray,
	records: Array[Dictionary],
	kept_offsets: Dictionary,
	region_start: int,
	region_end: int,
	entry_name: String,
	provenance_records: Array
) -> int:
	var pending: Array[int] = []
	for record in records:
		_collect_targets(record, pending)
	var added := 0
	var visited: Dictionary = {}
	while not pending.is_empty():
		var target: int = pending.pop_back()
		if target < region_start or target >= region_end or kept_offsets.has(target):
			continue
		if visited.has(target):
			continue
		visited[target] = true
		var cursor := target
		while cursor >= region_start and cursor < region_end and not kept_offsets.has(cursor):
			var instruction := _decoder.decode_at_structural(code, cursor, region_end)
			if not instruction.get("ok", false):
				records.append({
					"op": "opaque_region",
					"id": -1,
					"at": cursor,
					"end": region_end,
					"bytes": region_end - cursor,
					"reason": str(instruction.get("error", "jump target does not decode")),
				})
				kept_offsets[cursor] = true
				added += 1
				break
			if _is_provenance(instruction):
				provenance_records.append({"at": int(instruction.source_offset), "end": int(instruction.end_offset)})
				cursor = int(instruction.end_offset)
				continue
			var record := _project_instruction(instruction, code, entry_name)
			record["reached_by_transfer"] = true
			records.append(record)
			kept_offsets[cursor] = true
			added += 1
			_collect_targets(record, pending)
			cursor = int(instruction.end_offset)
	return added


func _collect_targets(record: Dictionary, output: Array[int]) -> void:
	for untyped_operand in record.get("operands", []):
		var operand: Dictionary = untyped_operand
		if str(operand.get("t", "")) == "code_offset":
			output.append(int(operand.v))
		elif str(operand.get("t", "")) == "u8_array" and int(record.get("id", -1)) == 0x10:
			var bytes: Array = operand.v
			if bytes.size() == 4:
				output.append(
					int(bytes[0])
					| (int(bytes[1]) << 8)
					| (int(bytes[2]) << 16)
					| (int(bytes[3]) << 24)
				)
	if record.has("skip_to"):
		output.append(int(record.skip_to))

func _project_instruction(
	instruction: Dictionary,
	code: PackedByteArray,
	entry_name: String
) -> Dictionary:
	var record := {
		"op": str(instruction.op),
		"id": int(instruction.command_id),
		"at": int(instruction.source_offset),
		"end": int(instruction.end_offset),
	}
	for key in instruction.keys():
		var name := str(key)
		if INSTRUCTION_FIELD_MAP.has(name):
			record[str(INSTRUCTION_FIELD_MAP[name])] = instruction[key]
			continue
		if DROPPED_INSTRUCTION_KEYS.has(name):
			continue
		if _is_dropped_analysis_key(name):
			_dropped_instruction_keys[name] = int(_dropped_instruction_keys.get(name, 0)) + 1
			continue
		_unclassified_operand_keys["instruction." + name] = true
	# The runner reads the byte stream for four decisions the package cannot
	# carry as bytes. All four are resolved here, against the archive.
	var probe: Dictionary = instruction.get("native_stream_probe", {})
	var consumed := int(probe.get("consumed_byte_count", 0))
	if consumed > 0:
		var probe_end := int(probe.get("probe_end_offset", -1))
		if probe_end > int(instruction.source_offset) and probe_end <= code.size():
			record["skip_to"] = probe_end
			record["skip_bytes"] = consumed
	var at := int(instruction.source_offset)
	if int(instruction.command_id) == 0x02:
		if at + 4 <= code.size() and code.slice(at, at + 4) == PackedByteArray([0x02, 0x02, 0xFF, 0x00]):
			record["dialogue_boundary_pattern"] = true
	# The message wait System.function[19](2) as one system call is the
	# archive's dialogue boundary (Core 0.316.0); its end is the resume offset.
	if (
		int(instruction.command_id) == 0x0D
		and str(instruction.get("op", "")) == "system_call"
		and int(instruction.get("system_function", -1)) == 19
		and at + 7 <= code.size()
		and code.slice(at, at + 7) == PackedByteArray([0x0D, 0x13, 0xFF, 0x02, 0x02, 0xFF, 0x00])
	):
		record["dialogue_boundary_pattern"] = true
	# A separator's first payload byte decides whether the runner treats a
	# native stream as a presentation boundary.
	if int(instruction.command_id) == 0x0D and consumed > 1 and at + 1 < code.size():
		record["payload_lead"] = int(code[at + 1])
	# A definition registration hashes its own body range.
	if int(instruction.command_id) == 0x10:
		var body := _definition_body_range(instruction, code.size())
		if not body.is_empty():
			record["body_sha256"] = _sha256_bytes(code.slice(int(body.start), int(body.end)))
	_projecting_offset = int(instruction.source_offset)
	var operands: Array = instruction.get("operands", [])
	if not operands.is_empty():
		var projected: Array[Dictionary] = []
		for untyped_operand in operands:
			projected.append(_project_operand(untyped_operand, entry_name))
		record["operands"] = projected
	return record


func _definition_body_range(instruction: Dictionary, code_size: int) -> Dictionary:
	var operands: Array = instruction.get("operands", [])
	if operands.size() != 2 or str(operands[1].get("type", "")) != "u8_array":
		return {}
	var target_bytes: Array = operands[1].value
	if target_bytes.size() != 4:
		return {}
	var target := (
		int(target_bytes[0])
		| (int(target_bytes[1]) << 8)
		| (int(target_bytes[2]) << 16)
		| (int(target_bytes[3]) << 24)
	)
	var body_offset := int(instruction.end_offset)
	if target <= body_offset or target > code_size:
		return {}
	return {"start": body_offset, "end": target}


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _project_operand(operand: Dictionary, entry_name: String) -> Dictionary:
	var type_name := str(operand.get("type", ""))
	match type_name:
		"expression", "condition", "expression_index":
			return {"t": type_name, "ast": _project_expression(operand.get("value", {}), entry_name)}
		"code_offset", "u8", "u8_index", "u16_index", "u8_bank", "entry_index", "source_line":
			return {"t": type_name, "v": int(operand.value)}
		"u8_array":
			return {"t": type_name, "v": operand.value}
		"cp932_bytes":
			return _project_text(operand)
		"resource_name":
			var resource_name := str(operand.get("name", ""))
			_resource_names[resource_name] = true
			var projected := {
				"t": type_name,
				"kind": str(operand.get("resource_kind", "")),
				"name": resource_name,
			}
			_classify_typed_keys(operand, projected, entry_name)
			return projected
		"expression_byte_pair":
			return {
				"t": type_name,
				"ast": _project_expression(operand.get("expression", {}), entry_name),
				"continuation": int(operand.get("continuation", 0)),
			}
		"expression_byte_pairs":
			var pairs: Array[Dictionary] = []
			for untyped_pair in operand.get("pairs", []):
				var pair: Dictionary = untyped_pair
				pairs.append({
					"ast": _project_expression(pair.get("expression", {}), entry_name),
					"continuation": int(pair.get("continuation", 0)),
				})
			return {"t": type_name, "pairs": pairs}
		"record_list":
			var records: Array[Dictionary] = []
			for untyped_sub in operand.get("records", []):
				records.append(_project_record(untyped_sub, entry_name))
			return {"t": type_name, "records": records}
		_:
			if not operand.has("type"):
				_unclassified_operand_types["<no type>"] = true
				return {"t": "unclassified"}
			var typed := {"t": type_name}
			_classify_typed_keys(operand, typed, entry_name)
			return typed


func _project_record(source: Dictionary, entry_name: String) -> Dictionary:
	var kind := str(source.get("type", ""))
	var projected := {"tag": int(source.get("tag", 0)), "kind": kind}
	match kind:
		"expression_record":
			projected["ast"] = _project_expression(source.get("value", {}), entry_name)
		"string_record":
			var text := _project_text(source.get("value", {}))
			if text.has("s"):
				projected["s"] = int(text.s)
			else:
				projected["hex"] = str(text.hex)
		"unknown_tag":
			pass
		_:
			_unclassified_operand_types["record." + kind] = true
	return projected


func _project_text(operand: Dictionary) -> Dictionary:
	var raw_bytes: PackedByteArray = operand.get("raw_bytes", PackedByteArray())
	if _active_text_projection.has(_projecting_offset):
		var edit: Dictionary = _active_text_projection[_projecting_offset]
		if _sha256_bytes(raw_bytes) != str(edit.raw_sha256):
			_failures.append("Authored text no longer matches its exact original message bytes.")
			return {}
		_used_text_offsets[_projecting_offset] = true
		var authored := str(edit.text)
		if not _text_index.has(authored):
			_text_index[authored] = _text_strings.size()
			_text_strings.append(authored)
		return {"t": "text", "s": int(_text_index[authored]), "source_hex": raw_bytes.hex_encode()}
	var decoded := _cp932.decode(raw_bytes)
	if not bool(decoded.get("ok", false)):
		_undecodable_text_count += 1
		return {"t": "text", "hex": str(operand.get("raw_hex", raw_bytes.hex_encode()))}
	var text := str(decoded.text)
	# The package stores UTF-8. A player that still speaks the runner's CP932
	# message API has to re-encode, so losslessness is proven here rather than
	# assumed there.
	var reencoded := _cp932.encode(text)
	if not bool(reencoded.get("ok", false)) or PackedByteArray(reencoded.data) != raw_bytes:
		_text_round_trip_failures += 1
		_undecodable_text_count += 1
		return {"t": "text", "hex": str(operand.get("raw_hex", raw_bytes.hex_encode()))}
	if not _text_index.has(text):
		_text_index[text] = _text_strings.size()
		_text_strings.append(text)
	return {"t": "text", "s": int(_text_index[text])}


func _project_expression(value, entry_name: String) -> Variant:
	if not value is Dictionary:
		_failures.append("%s: expression operand is not a dictionary" % entry_name)
		return {}
	var expression: Dictionary = value
	if not bool(expression.get("ok", false)):
		# Structural decoding keeps a boundary instead of an expression where the
		# strict evaluator cannot prove one. The package carries the boundary so
		# playback stops there exactly as the runner does, rather than inventing
		# a value.
		_unresolved_expression_count += 1
		return {"unresolved": str(expression.get("error", "expression boundary"))}
	return _reduce_ast(expression.get("ast", {}))


func _is_dropped_analysis_key(name: String) -> bool:
	return (
		name.begins_with("native_")
		or name.begins_with("tool_")
		or name.ends_with("_semantics")
	)


func _reduce_ast(node):
	if node is Dictionary:
		var reduced := {}
		for key in node.keys():
			if str(key) == "source":
				continue
			reduced[str(key)] = _reduce_ast(node[key])
		return reduced
	if node is Array:
		var items := []
		for item in node:
			items.append(_reduce_ast(item))
		return items
	return node


func _classify_typed_keys(operand: Dictionary, projected: Dictionary, entry_name: String) -> void:
	for key in operand.keys():
		var name := str(key)
		if projected.has(name) or DROPPED_OPERAND_KEYS.has(name):
			continue
		if _is_dropped_analysis_key(name) or DROPPED_TYPED_OPERAND_KEYS.has(name):
			_dropped_operand_keys[name] = int(_dropped_operand_keys.get(name, 0)) + 1
			continue
		if TYPED_OPERAND_KEEP.has(name):
			projected[name] = operand[key]
			continue
		if TYPED_OPERAND_EXPRESSION_KEYS.has(name):
			projected[name] = _project_expression(operand[key], entry_name)
			continue
		if TYPED_OPERAND_EXPRESSION_LIST_KEYS.has(name):
			var items: Array = []
			for untyped_expression in operand[key]:
				items.append(_project_expression(untyped_expression, entry_name))
			projected[name] = items
			continue
		if name == "records":
			var records: Array[Dictionary] = []
			for untyped_sub in operand[key]:
				records.append(_project_record(untyped_sub, entry_name))
			projected["records"] = records
			continue
		_unclassified_operand_keys["%s.%s" % [str(operand.get("type", "")), name]] = true


func _audit_targets(
	records: Array[Dictionary],
	kept_offsets: Dictionary,
	code_size: int
) -> Dictionary:
	var total := 0
	var on_record := 0
	var forward := 0
	var outside := 0
	var sorted_offsets := kept_offsets.keys()
	sorted_offsets.sort()
	for record in records:
		for untyped_operand in record.get("operands", []):
			var operand: Dictionary = untyped_operand
			if str(operand.get("t", "")) != "code_offset":
				continue
			var target := int(operand.v)
			total += 1
			if kept_offsets.has(target):
				on_record += 1
				continue
			if target < 0 or target >= code_size:
				outside += 1
				continue
			var resolved := false
			for offset in sorted_offsets:
				if int(offset) >= target:
					resolved = true
					break
			if resolved:
				forward += 1
			else:
				outside += 1
	return {
		"total": total,
		"on_kept_record": on_record,
		"resolves_forward": forward,
		"unresolved": outside,
	}


func _prepare_output(output_root: String) -> bool:
	for directory in [output_root, output_root + "/events", output_root + "/text"]:
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			if not DirAccess.dir_exists_absolute(directory):
				push_error("Could not create %s" % directory)
				return false
	return true


func _entry_stem(entry_name: String) -> String:
	return entry_name.get_basename().to_upper()


func _normalize_path(value: String) -> String:
	var path := value.replace("\\", "/")
	while path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
	return path
