extends "res://tools/content_suite/playback_package_export.gd"

const WorkspaceScript := preload("res://content_core/content_workspace.gd")
const ResolverScript := preload("res://content_core/content_resolver.gd")
const OverlayScript := preload("res://content_core/overlay_package.gd")
const ContextualScript := preload("res://tools/content_suite/mes_contextual_run.gd")
const BindingScript := preload("res://tools/content_suite/mes_authoring_binding.gd")
const SessionScript := preload("res://tools/content_suite/mes_authoring_session.gd")
const ChainScript := preload("res://content_core/mes_semantic_diff_chain.gd")

var _effective: Dictionary = {}
var _translations: Dictionary = {}
var _routes: Dictionary = {}


func build_workspace(source_root: String, workspace_root: String, event_ids: Array, proofs: Dictionary) -> Dictionary:
	_effective.clear()
	_translations.clear()
	_routes.clear()
	var workspace := WorkspaceScript.new()
	var opened := workspace.open(workspace_root, source_root)
	if not opened.get("ok", false):
		return _build_failure(str(opened.get("error", "Workspace could not be opened.")))
	var snapshot := workspace.get_snapshot()
	var reader := ArcReaderScript.new()
	if not reader.open(source_root.path_join("mes.arc")):
		workspace.close()
		return _build_failure(reader.last_error)
	var resolver := ResolverScript.new()
	resolver.register_original_archive("mes.arc", source_root.path_join("mes.arc"))
	var configured := resolver.configure_overlay(workspace_root)
	var prepared := _prepare(snapshot, workspace_root, event_ids, proofs, reader, resolver) if configured else _build_failure(resolver.last_error)
	var built := build(source_root, event_ids) if prepared.get("ok", false) else prepared
	if built.get("ok", false):
		built["workspace_binding"] = prepared.binding
		for event in built.events:
			if _routes.has(str(event.event_id)):
				var route: Dictionary = _routes[str(event.event_id)]
				event.source.callee.start_coordinate = int(route.start_coordinate)
				event.choices = route.choices
				event.terminals = route.terminals
		var refreshed := workspace.refresh()
		if not refreshed.get("ok", false) or workspace.get_snapshot() != snapshot:
			built = _build_failure("Workspace changed during playback export.")
	resolver.close()
	reader.close()
	workspace.close()
	return built


func _prepare(snapshot: Dictionary, root: String, event_ids: Array, proofs: Dictionary,
	reader: KakyuArcReader, resolver: KakyuContentResolver) -> Dictionary:
	var catalog := EventCatalogScript.new()
	if not catalog.load_file(CATALOG_PATH).get("ok", false) or event_ids.is_empty():
		return _build_failure("Select at least one catalog event for workspace export.")
	if str(snapshot.project.event_player.catalog_id) != str(catalog.get_summary().catalog_id):
		return _build_failure("Workspace and export catalogs differ.")
	var events: Array[Dictionary] = []
	for event_id in event_ids:
		var event := catalog.get_event(str(event_id))
		if event.is_empty():
			return _build_failure("Workspace export event is absent from the catalog.")
		events.append(event)
	var members: Array[Dictionary] = []
	var changed := {}
	var resolved := {}
	# EP-10 unit 5bc, part 4: mirror `build()`'s own scoped analysis-group
	# merge here too - a generated row's route needs its caller entry (never
	# part of `source_members_for_events`, which only ever names the callee
	# and its declared required_entries), and `build()` will refuse any
	# member this step did not resolve into `_effective`.
	var catalog_members := EventCatalogScript.source_members_for_events(events)
	var merged_members := analysis_group_members(ANALYSIS_GROUPS_DIR, catalog_members, events)
	if not merged_members.get("ok", false):
		return _build_failure("; ".join(PackedStringArray(merged_members.get("failures", []))))
	for member in merged_members.members:
		var entry := str(member.entry)
		var original := reader.get_entry_fingerprint(entry)
		if original != str(member.entry_sha256):
			return _build_failure("Workspace source member changed: %s" % entry)
		var payload := resolver.read_resolved(resolver.resolve("mes.arc", entry))
		var effective := _sha256_bytes(payload)
		if effective != original:
			if not proofs.get(entry) is Dictionary:
				return _build_failure("Changed workspace member lacks its semantic proof: %s" % entry)
			changed[entry] = true
		var text := OverlayScript.new().load_mes_text_projection(root, "mes.arc", entry, reader.get_archive_fingerprint(), original)
		if not text.get("ok", false):
			return _build_failure(str(text.get("error", "Workspace text was rejected.")))
		_effective[entry] = payload
		_translations[entry] = text.messages
		if effective != original:
			var raw: Dictionary = proofs[entry]
			var entry_bundle := {}
			var entry_proof: Dictionary = raw
			if raw.has("manifest"):
				entry_bundle = raw
				entry_proof = raw.get("proof", {})
			var entry_schema := str(entry_proof.get("schema", ""))
			if entry_schema == ChainScript.SCHEMA and entry_bundle.is_empty():
				return _build_failure("Changed workspace member needs its stepped authoring bundle: %s" % entry)
			resolved[entry] = {"proof": entry_proof, "bundle": entry_bundle}
			if entry_schema == "kakyu_mes_semantic_diff/v4":
				var bound := BindingScript.bind(reader.read_entry(entry), payload, entry_proof)
				var mapped := BindingScript.map_text(text.messages, bound) if bound.get("ok", false) else bound
				if not mapped.get("ok", false):
					return _build_failure(str(mapped.get("error", "Workspace translation mapping failed.")))
				_translations[entry] = mapped.messages
			elif entry_schema == ChainScript.SCHEMA:
				var validated := SessionScript.validate_source(entry_bundle, reader.read_entry(entry))
				if not validated.get("ok", false):
					return _build_failure(str(validated.get("error", "Workspace translation mapping failed.")))
				if validated.has("points"):
					var mapped_chain := BindingScript.map_text(text.messages, validated)
					if not mapped_chain.get("ok", false):
						return _build_failure(str(mapped_chain.get("error", "Workspace translation mapping failed.")))
					_translations[entry] = mapped_chain.messages
		members.append({"entry": entry, "role": str(member.role), "source_entry_sha256": original,
			"effective_entry_sha256": effective, "authored_text_count": text.messages.size()})
	var bindings: Array[Dictionary] = []
	var proved := {}
	var external_terminals: Array[Dictionary] = []
	for event in events:
		var entry := str(event.source.callee.entry)
		if changed.has(entry):
			var preset_id := str(event.presets[0].preset_id) if not event.presets.is_empty() else ""
			var entry_resolved: Dictionary = resolved.get(entry, {})
			var run := ContextualScript.new().run(reader, resolver, catalog, catalog.build_play_request(str(event.event_id), preset_id), entry_resolved.get("proof", {}), entry_resolved.get("bundle", {}))
			if not run.get("ok", false):
				return _build_failure(str(run.get("error", "Changed event context was rejected.")))
			bindings.append(run.binding)
			_routes[str(event.event_id)] = run.route
			proved[entry] = true
		for terminal in event.terminals:
			if not _effective.has(str(terminal.owner_entry)):
				external_terminals.append({"event_id": str(event.event_id), "terminal_id": str(terminal.terminal_id), "owner_entry": str(terminal.owner_entry), "offset": int(terminal.offset)})
	if proved.size() != changed.size():
		return _build_failure("Changed shared dependencies are outside the first workspace export proof scope.")
	return {"ok": true, "binding": {
		"schema": "kakyu_workspace_playback_binding/v2", "project_id": str(snapshot.project.project_id),
		"generation_sha256": str(snapshot.generation_sha256), "project_sha256": str(snapshot.project_sha256),
		"manifest_sha256": str(snapshot.manifest_sha256), "members": members, "contextual_runs": bindings,
		"distribution": "local_original_content", "standalone_complete": false,
		"incompleteness": {"media_extraction": "deferred", "external_terminals": external_terminals},
	}}


func _read_payload(_reader: KakyuArcReader, entry: String) -> PackedByteArray:
	return _effective.get(entry, PackedByteArray())


func _text_projection(entry: String) -> Dictionary:
	return _translations.get(entry, {})
