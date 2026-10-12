class_name KakyuPlaybackPackageIntegrity
extends RefCounted

const Version := preload("res://content_core/content_core_version.gd")
const Fingerprint := preload("res://content_core/mes_payload_fingerprint.gd")
const InventoryScript := preload("res://content_core/playback_package_inventory.gd")

const MEMBERSHIP_RULE_FULL := "catalog_events_and_analysis_group_members"
const MEMBERSHIP_RULE_SELECTED := "selected_catalog_events"
const ROLE_ANALYSIS_GROUP_MEMBER := "analysis_group_member"


func bind(manifest: Dictionary, files: Array) -> Dictionary:
	var bound := manifest.duplicate(true)
	var inventory: Array[Dictionary] = []
	for file in files:
		inventory.append({"name": file.name, "size": file.size, "sha256": file.sha256})
	inventory.sort_custom(func(a, b): return str(a.name) < str(b.name))
	bound["files"] = inventory
	bound["package_sha256"] = fingerprint(bound)
	return bound


func fingerprint(manifest: Dictionary) -> String:
	var bound := manifest.duplicate(true)
	bound.erase("package_sha256")
	# Nest the manifest so the shared helper's reserved payload_sha256 exclusion
	# cannot discard any manifest field. This is a new v4 hash domain.
	return Fingerprint.new().fingerprint({"manifest": bound})


func manifest_error(manifest: Dictionary) -> String:
	if manifest.get("schema") != Version.PLAYBACK_PACKAGE_SCHEMA:
		return "Package schema is not %s; re-export older packages from their source." % Version.PLAYBACK_PACKAGE_SCHEMA
	var workspace_problem := _workspace_error(manifest)
	if not workspace_problem.is_empty():
		return workspace_problem
	for field in ["entries", "events", "files"]:
		if not manifest.get(field) is Array or manifest[field].is_empty():
			return "Manifest %s must be a nonempty array." % field
	var expected_files := {}
	var members := {}
	for report in manifest.entries:
		if not report is Dictionary or not safe_entry(report.get("entry")) or not is_sha256(report.get("entry_sha256")):
			return "Manifest entry identity is invalid."
		var entry: String = report.entry
		var stem := entry.get_basename()
		if members.has(entry) or expected_files.has("events/%s.json" % stem):
			return "Manifest has duplicate entry or file identities."
		members[entry] = true
		for group in ["events", "text"]:
			expected_files["%s/%s.json" % [group, stem]] = true
	var actual_files := {}
	var previous := ""
	for file in manifest.files:
		if not file is Dictionary or not file.get("name") is String:
			return "Manifest file record is invalid."
		var name: String = file.name
		if not expected_files.has(name) or actual_files.has(name) or name <= previous:
			return "Manifest file inventory is unexpected, duplicated, or unsorted."
		if not is_sha256(file.get("sha256")) or not is_coordinate(file.get("size")) or int(file.size) == 0:
			return "Manifest file fingerprint or size is invalid."
		actual_files[name] = true
		previous = name
	if actual_files.size() != expected_files.size():
		return "Manifest file inventory is incomplete."
	var event_ids := {}
	for event in manifest.events:
		if not event is Dictionary or not event.get("event_id") is String or event.event_id.is_empty():
			return "Manifest event identity is invalid."
		if event_ids.has(event.event_id) or not event.get("entry") is String or not members.has(event.entry):
			return "Manifest event identity is duplicated or names an absent entry."
		event_ids[event.event_id] = true
		if not is_coordinate(event.get("start_coordinate")):
			return "Manifest event start coordinate is invalid."
		for field in ["presets", "choices", "terminals"]:
			if not event.get(field) is Array:
				return "Manifest event %s must be an array." % field
			for row in event[field]:
				if not row is Dictionary:
					return "Manifest event %s contains a non-object." % field
		for terminal in event.terminals:
			if not is_coordinate(terminal.get("offset")):
				return "Manifest terminal coordinate is invalid."
	var profiles: Dictionary = {}
	if manifest.has("membership"):
		var membership: Variant = manifest.get("membership")
		if not membership is Dictionary:
			return "Manifest membership is inconsistent with its entries."
		if membership.get("rule") != MEMBERSHIP_RULE_FULL and membership.get("rule") != MEMBERSHIP_RULE_SELECTED:
			return "Manifest membership is inconsistent with its entries."
		for key in ["catalog_events", "catalog_members", "analysis_group_members"]:
			if not is_coordinate(membership.get(key)):
				return "Manifest membership is inconsistent with its entries."
		var analysis_group_member_count := 0
		for report in manifest.entries:
			if report is Dictionary and str(report.get("role", "")) == ROLE_ANALYSIS_GROUP_MEMBER:
				analysis_group_member_count += 1
		if int(membership.catalog_members) + int(membership.analysis_group_members) != manifest.entries.size():
			return "Manifest membership is inconsistent with its entries."
		if analysis_group_member_count != int(membership.analysis_group_members):
			return "Manifest membership is inconsistent with its entries."
		if int(membership.catalog_events) != manifest.events.size():
			return "Manifest membership is inconsistent with its entries."
		var groups: Variant = membership.get("analysis_groups")
		if not groups is Array:
			return "Manifest membership is inconsistent with its entries."
		var previous_profile := ""
		var payload_hashes: Dictionary = {}
		for group in groups:
			if (
				not group is Dictionary
				or not group.get("profile") is String or (group.profile as String).is_empty()
				or not group.get("group_id") is String or (group.group_id as String).is_empty()
				or not group.get("schema") is String or (group.schema as String).is_empty()
				or not is_sha256(group.get("payload_sha256"))
			):
				return "Manifest membership is inconsistent with its entries."
			var profile: String = group.profile
			if profiles.has(profile) or (previous_profile != "" and profile <= previous_profile):
				return "Manifest membership is inconsistent with its entries."
			var payload_sha256: String = group.payload_sha256
			if payload_hashes.has(payload_sha256):
				return "Manifest membership is inconsistent with its entries."
			payload_hashes[payload_sha256] = true
			profiles[profile] = true
			previous_profile = profile
		for report in manifest.entries:
			var bound_by: Variant = report.get("bound_by")
			if bound_by == null:
				continue
			if not bound_by is Array:
				return "Manifest membership is inconsistent with its entries."
			var previous_id := ""
			for profile_id in bound_by:
				if not profile_id is String or not profiles.has(profile_id) or (previous_id != "" and profile_id <= previous_id):
					return "Manifest membership is inconsistent with its entries."
				previous_id = profile_id
			if str(report.get("role", "")) == ROLE_ANALYSIS_GROUP_MEMBER and (bound_by as Array).is_empty():
				return "Manifest membership is inconsistent with its entries."
	if manifest.has("incompleteness"):
		var incompleteness: Variant = manifest.get("incompleteness")
		if not incompleteness is Dictionary:
			return "Manifest incompleteness is invalid."
		if incompleteness.get("standalone_complete") != false:
			return "Manifest incompleteness must declare the package incomplete."
		if incompleteness.get("media_extraction") != "deferred":
			return "Manifest incompleteness is invalid."
		if not incompleteness.get("external_terminals") is Array:
			return "Manifest incompleteness is invalid."
		var normalized_stored: Array[Dictionary] = []
		for untyped_row in (incompleteness.external_terminals as Array):
			if not untyped_row is Dictionary:
				return "Manifest incompleteness is invalid."
			var row: Dictionary = untyped_row
			if not is_coordinate(row.get("offset")):
				return "Manifest incompleteness is invalid."
			normalized_stored.append({
				"event_id": str(row.get("event_id", "")),
				"terminal_id": str(row.get("terminal_id", "")),
				"owner_entry": str(row.get("owner_entry", "")),
				"offset": int(row.get("offset", 0)),
			})
		var recomputed := _external_terminals(manifest.events, members)
		if JSON.stringify(normalized_stored) != JSON.stringify(recomputed):
			return "Manifest incompleteness external terminals do not match the package."
	if not is_sha256(manifest.get("package_sha256")) or fingerprint(manifest) != manifest.package_sha256:
		return "Package hash does not match its manifest and file inventory."
	return ""


# The manifest's `media_inventory` and `script_references` blocks, recomputed
# from the loaded member documents (WD-21 U1). `documents` and `strings` map each
# member entry to its document and its text strings. "" when the manifest carries
# neither block; an unknown block schema id, a block that differs from the
# records, or a name without identity fails closed. A name the original archives
# do not ship (`shipped: false`) is a recorded fact, never an error here, and this
# method never opens an archive.
func inventory_error(manifest: Dictionary, documents: Dictionary, strings: Dictionary) -> String:
	return InventoryScript.new().inventory_error(manifest, documents, strings)


func safe_entry(value: Variant) -> bool:
	if not value is String or value.is_empty() or value != value.to_upper():
		return false
	var expression := RegEx.new()
	expression.compile("^[A-Z0-9_]+(\\.[A-Z0-9_]+)*\\.(MES|LIB)$")
	return expression.search(value) != null


func document_error(document: Dictionary, text: Dictionary, report: Dictionary) -> String:
	for member in [document, text]:
		if member.get("schema") != Version.PLAYBACK_PACKAGE_SCHEMA or member.get("entry") != report.entry:
			return "Document schema or entry identity does not match its manifest."
	if document.get("entry_sha256") != report.entry_sha256 or not is_sha256(document.get("code_sha256")):
		return "Document source fingerprint does not match its manifest."
	if text.get("encoding") != "utf-8" or not text.get("strings") is Array:
		return "Text document must contain UTF-8 strings."
	for value in text.strings:
		if not value is String:
			return "Text document contains a non-string."
	var address_table: Variant = document.get("address_table", [] if document.get("kind") == "library" else null)
	if not is_coordinate(document.get("code_size")) or int(document.code_size) == 0 or not address_table is Array:
		return "Document code size or address table is invalid."
	var previous := -1
	for offset in address_table:
		if not is_coordinate(offset) or int(offset) <= previous or int(offset) >= int(document.code_size):
			return "Document address table is not strictly ordered within its code."
		previous = int(offset)
	var groups: Array = [document]
	if document.get("kind", "event") == "library":
		if not document.get("routines") is Array:
			return "Library routines must be an array."
		groups = document.routines
	var routine_ids := {}
	for group in groups:
		if not group is Dictionary or not group.get("records") is Array:
			return "Document record group is invalid."
		if not group.get("provenance_records") is Array:
			return "Document dropped-provenance boundaries must be an array."
		var provenance_ends := {}
		for span in group.provenance_records:
			if not span is Dictionary or not valid_span(span, int(document.code_size)):
				return "Dropped-provenance record boundary is invalid."
			if provenance_ends.has(int(span.at)) and int(provenance_ends[int(span.at)]) != int(span.end):
				return "Dropped-provenance boundaries disagree at one offset."
			provenance_ends[int(span.at)] = int(span.end)
		if document.get("kind", "event") == "library":
			if not is_coordinate(group.get("routine_id")) or routine_ids.has(group.routine_id) or not valid_span(group, int(document.code_size)):
				return "Library routine identity or range is invalid."
			routine_ids[group.routine_id] = true
		for record in group.records:
			if not record is Dictionary or not valid_span(record, int(document.code_size)) or not record.get("op") is String:
				return "Document record boundary or operation is invalid."
			if record.op != "opaque_region" and (not is_coordinate(record.get("id")) or not record.get("operands", []) is Array):
				return "Document record command or operands are invalid."
			if not _text_references_valid(record.get("operands", []), text.strings.size()):
				return "Document text reference or retained source text is invalid."
	return ""


func _external_terminals(events: Array, members: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for untyped_event in events:
		if not untyped_event is Dictionary:
			continue
		var event: Dictionary = untyped_event
		var event_id := str(event.get("event_id", ""))
		for untyped_terminal in event.get("terminals", []):
			if not untyped_terminal is Dictionary:
				continue
			var terminal: Dictionary = untyped_terminal
			var owner: Variant = terminal.get("owner_entry")
			if not owner is String or members.has(owner):
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


func _workspace_error(manifest: Dictionary) -> String:
	var binding = manifest.get("workspace_binding")
	if not binding is Dictionary:
		return "Package workspace binding must be explicit."
	if binding.is_empty():
		return ""
	if binding.get("schema") != "kakyu_workspace_playback_binding/v2" or binding.get("distribution") != "local_original_content" or binding.get("standalone_complete") != false:
		return "Workspace package scope or schema is invalid."
	for key in ["generation_sha256", "project_sha256", "manifest_sha256"]:
		if not is_sha256(binding.get(key)):
			return "Workspace package identity is invalid."
	if not binding.get("members") is Array or not binding.get("contextual_runs") is Array or not binding.get("incompleteness") is Dictionary:
		return "Workspace package dependencies are invalid."
	if binding.incompleteness.get("media_extraction") != "deferred" or not binding.incompleteness.get("external_terminals") is Array:
		return "Workspace package incompleteness is missing."
	var entries := {}
	for report in manifest.get("entries", []):
		if report is Dictionary:
			entries[report.get("entry", "")] = report.get("entry_sha256", "")
	var seen := {}
	for member in binding.members:
		if not member is Dictionary or not safe_entry(member.get("entry")) or seen.has(member.entry):
			return "Workspace member identity is invalid or duplicated."
		if not is_sha256(member.get("source_entry_sha256")) or member.get("effective_entry_sha256") != entries.get(member.entry) or not is_coordinate(member.get("authored_text_count")):
			return "Workspace member differs from the effective package."
		seen[member.entry] = true
	if seen.size() != entries.size():
		return "Workspace member inventory is incomplete."
	for run in binding.contextual_runs:
		if not run is Dictionary or run.get("schema") not in ["kakyu_mes_contextual_run_binding/v1", "kakyu_mes_contextual_run_binding/v2", "kakyu_mes_contextual_run_binding/v3"] or Fingerprint.new().fingerprint(run) != run.get("payload_sha256"):
			return "Workspace contextual proof binding is invalid."
		var event := {}
		for candidate in manifest.get("events", []):
			if candidate.get("event_id") == run.get("event_id"):
				event = candidate
		if event.is_empty() or run.get("effective_entry_sha256") != entries.get(event.get("entry")) or not run.get("points") is Array:
			return "Workspace contextual event differs from its packaged entry."
		var expected: Array = [{"role": "start", "owner": event.entry, "output": event.start_coordinate}]
		for choice in event.choices:
			expected.append({"role": "choice", "owner": choice.owner_entry, "output": choice.boundary_offset})
		for terminal in event.terminals:
			expected.append({"role": "terminal", "owner": terminal.owner_entry, "output": terminal.offset})
		if expected.size() != run.points.size():
			return "Workspace control-point inventory differs from the package."
		var run_schema := str(run.get("schema", ""))
		var chain_policy := str(run.get("coordinate_policy", "")) if run_schema == "kakyu_mes_contextual_run_binding/v3" else ""
		var chain_relocated := chain_policy == "chained_same_size_then_relocation"
		var chain_same_size := chain_policy == "chained_same_size_patches"
		for index in range(expected.size()):
			var point = run.points[index]
			if not point is Dictionary or not is_coordinate(point.get("source")):
				return "Workspace source control-point coordinate is invalid."
			for key in expected[index]:
				if point.get(key) != expected[index][key]:
					return "Workspace mapped control point differs from the package."
			if (run_schema == "kakyu_mes_contextual_run_binding/v1" or chain_same_size) and point.source != point.output:
				return "Identity-preserved context contains a relocated point."
		if run_schema == "kakyu_mes_contextual_run_binding/v1" and run.get("coordinate_policy") not in ["identity_preserved_state_literal", "identity_preserved_same_size_patch"]:
			return "Workspace identity coordinate policy is invalid."
		if run_schema == "kakyu_mes_contextual_run_binding/v3":
			if not chain_relocated and not chain_same_size:
				return "Workspace chained coordinate policy is invalid."
			if not is_sha256(run.get("chain_proof_sha256")) or not is_coordinate(run.get("step_count")) or int(run.get("step_count", 0)) < 2:
				return "Workspace chain proof evidence is incomplete."
		if run_schema == "kakyu_mes_contextual_run_binding/v2" and (run.get("coordinate_policy") != "reconstructed_message_relocation" or not is_sha256(run.get("coordinate_binding_sha256")) or not run.get("terminal_observation") is Dictionary):
			return "Workspace relocation evidence is incomplete."
		if chain_relocated and (not is_sha256(run.get("coordinate_binding_sha256")) or not run.get("terminal_observation") is Dictionary):
			return "Workspace relocation evidence is incomplete."
		if run_schema == "kakyu_mes_contextual_run_binding/v2" or chain_relocated:
			if not run.get("resume_points") is Array or run.resume_points.size() != event.terminals.size():
				return "Workspace terminal resume inventory is incomplete."
			for index in range(event.terminals.size()):
				var terminal: Dictionary = event.terminals[index]
				var point = run.resume_points[index]
				var owner := str(run.get("caller_intro", {}).get("entry", "")) if terminal.kind == "callee_return_only" else str(terminal.owner_entry)
				if not point is Dictionary or point.get("terminal_id") != terminal.terminal_id or point.get("owner") != owner or not is_coordinate(point.get("source")) or point.get("output") != terminal.caller_resume_offset:
					return "Workspace terminal resume differs from the mapped package."
	return ""


func _text_references_valid(value: Variant, string_count: int) -> bool:
	if value is Array:
		for child in value:
			if not _text_references_valid(child, string_count):
				return false
	elif value is Dictionary:
		if value.get("t") == "text":
			if value.has("s") and (not is_coordinate(value.s) or int(value.s) >= string_count):
				return false
			if value.has("source_hex"):
				if not value.has("s") or not value.source_hex is String or value.source_hex.length() % 2 != 0:
					return false
				for character in value.source_hex:
					if character not in "0123456789abcdef":
						return false
		for child in value.values():
			if not _text_references_valid(child, string_count):
				return false
	return true


func valid_span(record: Dictionary, code_size: int) -> bool:
	return is_coordinate(record.get("at")) and is_coordinate(record.get("end")) and int(record.at) < int(record.end) and int(record.end) <= code_size


func is_coordinate(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) <= 0xFFFFFFFF


func is_sha256(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true
