extends "res://tools/content_suite/cli_script.gd"

const EventCatalogScript := preload("res://content_core/event_catalog.gd")
const ContentSetScript := preload("res://content_core/content_set.gd")
const MesContainerScript := preload("res://content_core/mes_container.gd")
const MesAnalysisScript := preload("res://content_core/mes_analysis_index.gd")
const MesEventRunnerScript := preload("res://content_core/mes_event_runner.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const CATALOG_PATH := "res://config/event_catalog/original_events_v1.json"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Usage: <ELFIMAGE-directory>")
		return
	var source_root := ProjectSettings.globalize_path(str(arguments[0])).simplify_path()
	var archive_path := source_root.path_join("mes.arc")
	var source_sha := FileAccess.get_sha256(archive_path)
	if source_sha.is_empty():
		_fail("Original MES archive is unavailable.")
		return
	var catalog := EventCatalogScript.new()
	var loaded: Dictionary = catalog.load_file(CATALOG_PATH)
	if not loaded.get("ok", false):
		_fail("Seeded Event Catalog is invalid: %s" % catalog.last_error)
		return
	var content_set := ContentSetScript.new()
	if not content_set.open(source_root):
		_fail("Original content set could not be opened: %s" % content_set.last_error)
		return
	var source_hashes := {}
	for archive_name in content_set.get_archive_names():
		var archive_reader = content_set.get_reader(archive_name)
		source_hashes[archive_name] = FileAccess.get_sha256(str(archive_reader.archive_path))
	var summary: Dictionary = catalog.get_summary()
	var document_file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var document = JSON.parse_string(document_file.get_as_text()) if document_file != null else null
	if document_file != null:
		document_file.close()
	if not document is Dictionary or str(document.source_profile.mes_archive.sha256) != source_sha:
		content_set.close()
		_fail("Seeded Event Catalog source archive fingerprint does not match the configured original.")
		return
	var bindings := {}
	var caller_routes := 0
	var terminal_boundaries := 0
	var terminal_source_indexes := {}
	for event_value in catalog.get_events():
		var event: Dictionary = event_value
		var source: Dictionary = event.source
		if source.has("caller"):
			if not _check_binding(content_set, source.caller, str(event.event_id), "caller", bindings):
				content_set.close()
				return
		if not _check_binding(content_set, source.callee, str(event.event_id), "callee", bindings):
			content_set.close()
			return
		for required_value in source.required_entries:
			if not _check_binding(content_set, required_value, str(event.event_id), str(required_value.role), bindings):
				content_set.close()
				return
		var terminal_validation := _check_terminal_boundaries(content_set, event, terminal_source_indexes)
		if not terminal_validation.get("ok", false):
			content_set.close()
			_fail(str(terminal_validation.get("error", "Event Catalog terminal validation failed.")))
			return
		terminal_boundaries += int(terminal_validation.count)
	for archive_name in source_hashes:
		var archive_reader = content_set.get_reader(str(archive_name))
		if FileAccess.get_sha256(str(archive_reader.archive_path)) != str(source_hashes[archive_name]):
			content_set.close()
			_fail("Event Catalog validation changed a source archive.")
			return
	content_set.close()
	print(
		"PASS: Event Catalog original content-set bindings events=%d unique_entries=%d caller_routes=%d terminal_boundaries=%d classifications=%s statuses=%s source_unchanged=true"
		% [int(summary.event_count), bindings.size(), caller_routes, terminal_boundaries, JSON.stringify(summary.classification_counts), JSON.stringify(summary.playback_status_counts)]
	)
	quit(0)


func _check_binding(content_set, binding: Dictionary, event_id: String, role: String, bindings: Dictionary) -> bool:
	var archive_name := str(binding.get("archive", "")).to_lower()
	var reader = content_set.get_reader(archive_name)
	if reader == null or not reader.is_open():
		_fail("%s %s binding targets an unavailable archive." % [event_id, role])
		return false
	var entry_name := str(binding.get("entry", ""))
	var expected_sha := str(binding.get("entry_sha256", ""))
	var actual_sha: String = reader.get_entry_fingerprint(entry_name)
	if actual_sha.is_empty() or actual_sha != expected_sha:
		_fail("%s %s binding does not match original %s:%s." % [event_id, role, archive_name, entry_name])
		return false
	var key := "%s:%s" % [archive_name, entry_name.to_upper()]
	if bindings.has(key) and str(bindings[key]) != expected_sha:
		_fail("Catalog binds %s to conflicting hashes." % entry_name)
		return false
	bindings[key] = expected_sha
	return true


func _check_terminal_boundaries(content_set, event: Dictionary, source_indexes: Dictionary) -> Dictionary:
	var count := 0
	for terminal in event.get("terminals", []):
		var runtime_status := str(terminal.get("runtime_status", ""))
		if str(terminal.get("evidence_level", "")) != "confirmed" or runtime_status not in ["script_handoff_boundary", "script_return"]:
			continue
		var source_index := _terminal_source_index(content_set, event, str(terminal.owner_entry), source_indexes)
		if not source_index.get("ok", false):
			return source_index
		var offset := int(terminal.offset)
		var instruction: Dictionary = source_index.instructions_by_offset.get(offset, {})
		var aligned := not instruction.is_empty()
		if runtime_status == "script_handoff_boundary":
			aligned = (
				aligned
				and int(instruction.get("command_id", -1)) == 0x0E
				and str(instruction.get("op", "")) == "script_handoff_marker"
				and not str(terminal.get("next_target", "")).is_empty()
				and str(instruction.get("script_target", "")).to_upper() == str(terminal.next_target).to_upper()
			)
		else:
			aligned = (
				aligned
				and int(instruction.get("command_id", -1)) == 0x00
				and str(instruction.get("op", "")) == "command_00"
				and int(instruction.get("byte_length", -1)) == 1
				and int(instruction.get("end_offset", -1)) == offset + 1
			)
		if not aligned:
			return {"ok": false, "error": "%s terminal %s does not match an indexed %s in %s at 0x%X." % [str(event.event_id), str(terminal.terminal_id), runtime_status, str(terminal.owner_entry), offset]}
		# The structural index establishes the owning record only. The event's
		# route regression, rather than this audit, proves branch/state reachability.
		print("EVENT_CATALOG_TERMINAL_BOUNDARY " + JSON.stringify({
			"schema": "kakyu_event_catalog_terminal_boundary_audit/v1",
			"event_id": str(event.event_id), "terminal_id": str(terminal.terminal_id),
			"owner_entry": str(source_index.entry), "owner_entry_sha256": str(source_index.entry_sha256),
			"offset": offset, "end_offset": int(instruction.end_offset),
			"command_id": int(instruction.command_id), "runtime_status": runtime_status,
			"next_target": str(terminal.get("next_target", "")).to_upper(),
			"boundary_policy": "structural_indexed_instruction",
			"branch_reachability_verified": false, "required_state_verified": false,
			"outer_host_executed": false,
		}, "", true, true))
		count += 1
	return {"ok": true, "count": count}


func _terminal_source_index(content_set, event: Dictionary, owner_entry: String, source_indexes: Dictionary) -> Dictionary:
	var source: Dictionary = event.source
	var candidates: Array = [source.callee]
	if source.has("caller"):
		candidates.append(source.caller)
	candidates.append_array(source.required_entries)
	var binding: Dictionary = {}
	for candidate in candidates:
		if str(candidate.get("entry", "")).to_upper() != owner_entry.to_upper():
			continue
		if not binding.is_empty() and (
			str(binding.archive).to_lower() != str(candidate.archive).to_lower()
			or str(binding.entry_sha256) != str(candidate.entry_sha256)
		):
			return {"ok": false, "error": "%s terminal owner %s has ambiguous source bindings." % [str(event.event_id), owner_entry]}
		binding = candidate
	if binding.is_empty():
		return {"ok": false, "error": "%s terminal owner %s has no source hash binding." % [str(event.event_id), owner_entry]}
	var key := "%s:%s:%s" % [str(binding.archive).to_lower(), owner_entry.to_upper(), str(binding.entry_sha256)]
	if source_indexes.has(key):
		return source_indexes[key]
	var data: PackedByteArray = content_set.read_entry(str(binding.archive), str(binding.entry))
	var document := MesContainerScript.new().parse(data, {"archive": str(binding.archive), "entry": str(binding.entry)})
	if not document.get("ok", false) or str(document.get("entry_sha256", "")) != str(binding.entry_sha256):
		return {"ok": false, "error": "%s terminal owner %s could not be parsed or changed after source binding validation." % [str(event.event_id), owner_entry]}
	var analysis := MesAnalysisScript.new().build_structural(document)
	if not analysis.get("ok", false):
		return {"ok": false, "error": "%s terminal owner %s could not be structurally indexed." % [str(event.event_id), owner_entry]}
	var instructions_by_offset := {}
	for instruction in analysis.get("instructions", []):
		instructions_by_offset[int(instruction.source_offset)] = instruction
	var indexed := {
		"ok": true, "entry": owner_entry.to_upper(), "entry_sha256": str(binding.entry_sha256),
		"instructions_by_offset": instructions_by_offset,
	}
	source_indexes[key] = indexed
	return indexed


