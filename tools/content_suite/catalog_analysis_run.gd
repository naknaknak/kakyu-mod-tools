extends RefCounted

const CatalogScript := preload("res://content_core/event_catalog.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const ProbeScript := preload("res://content_core/mes_route_probe.gd")
const FingerprintScript := preload("res://content_core/mes_payload_fingerprint.gd")
const SandboxStateScript := preload("res://content_core/mes_sandbox_state.gd")
const CalendarScript := preload("res://content_core/mes_calendar_state.gd")
const GuardFormScript := preload("res://content_core/event_guard_form.gd")
const FlowRunnerScript := preload("res://tools/content_suite/event_flow_runner.gd")

## EP-12 catalog part (2026-09-24): a v14 profile document names a flow -
## one hop chain per route, no per-route `caller`/`callee` pair - so
## `build_group_route_descriptor` does not apply to it;
## `_run_group_flow_route` runs it through the shared `KakyuEventFlowRunner`
## instead. See `docs/spec/tech/content_tools.md`'s v14 entry.
const FLOW_SCHEMA := "kakyu_event_analysis_group/v14"


func readiness_group(reader, resolver, catalog, profiles, request: Dictionary) -> Dictionary:
	# EP-10 unit 2: a promoted analysis-group row's readiness. The profile is
	# the authority for the route and variant; the catalog request is only
	# re-derived and compared, exactly as `readiness` does for a bounded
	# analysis route.
	if not request.get("ok", false):
		return _error("The catalog request is unavailable.")
	if str(request.get("execution_model", "")) != "group_route":
		return _error("The catalog request is not an analysis-group route.")
	var event: Dictionary = catalog.get_event(str(request.get("event_id", "")))
	if not event.has("analysis_group"):
		return _error("The catalog does not declare an analysis group.")
	# Round 9 code review, item 3: a malformed request (no preset dict, or a
	# source profile missing its mes.arc fingerprint) is refused here rather
	# than crashing on the untyped reads below.
	var preset_value = request.get("preset", null)
	if not preset_value is Dictionary:
		return _error("The analysis request is malformed.")
	var preset: Dictionary = preset_value
	var source_profile_value = request.get("source_profile", null)
	if (
		not source_profile_value is Dictionary
		or not (source_profile_value as Dictionary).get("mes_archive", null) is Dictionary
		or not ((source_profile_value as Dictionary).mes_archive as Dictionary).has("sha256")
	):
		return _error("The analysis request is malformed.")
	var source_profile: Dictionary = source_profile_value
	var selection: Dictionary = request.get("selection", {})
	var option_id := str(selection.get("option_id", ""))
	# Round 3 code review, item 4: `tool_seeded_analysis` is a legal catalog
	# preset kind on its own (`PRESET_KINDS`), so the tool-seeded path is
	# keyed on the presence of `base_preset_id` - only `_build_group_route_request`
	# ever sets that key - not on the preset's kind.
	var is_tool_seeded := preset.has("base_preset_id")
	var canonical: Dictionary
	if is_tool_seeded:
		canonical = catalog.build_play_request(str(event.event_id), str(preset.get("base_preset_id", "")), option_id, preset)
	else:
		canonical = catalog.build_play_request(str(event.event_id), str(preset.get("preset_id", "")), option_id)
	if not canonical.get("ok", false) or canonical != request:
		return _error("The analysis request differs from the current catalog and preset.")
	if not reader.is_open() or reader.get_archive_fingerprint() != str(source_profile.mes_archive.sha256):
		return _error("The analysis route requires its source-bound mes.arc.")
	# Round 3 code review, item 5: every member is parsed here, once, and the
	# parsed documents are returned so `run_group_route` and the tool-seeded
	# guard check reuse them instead of re-reading and re-parsing the same
	# entries.
	var members := CatalogScript.source_members_for_events([event])
	members.append(event.source.caller)
	var documents := {}
	for member in members:
		var name := str(member.entry)
		if str(member.get("archive", "mes.arc")).to_lower() != "mes.arc" or reader.get_entry_fingerprint(name) != str(member.entry_sha256):
			return _error("The analysis source identity changed: %s" % name)
		var resolved: Dictionary = resolver.resolve("mes.arc", name)
		var resolved_bytes: PackedByteArray = resolver.read_resolved(resolved)
		if not resolved.get("ok", false) or FingerprintScript.new().sha256_bytes(resolved_bytes) != str(member.entry_sha256):
			return _error("The analysis route requires unchanged MES dependencies: %s" % name)
		var document := ContainerScript.new().parse(resolved_bytes, {"entry": name})
		if not document.get("ok", false):
			return _error("The analysis dependency cannot be parsed: %s" % name)
		documents[name] = document
	# Owner ruling (2026-09-20, round 6): a route id is not unique across a
	# row's groups (the same route id can legitimately appear in more than
	# one group, or under more than one profile version of the same
	# group_id), so the preset itself - not a search by selection or by
	# terminal coordinate - is the primary key of a run: its notes name the
	# exact group, route and variant. The selection is only a consistency
	# check afterward.
	#
	# EP-10 unit 3: a tool-seeded preset carries no such notes of its own -
	# it names the catalog preset it started from (`base_preset_id`), and
	# the group/route/variant are resolved from that preset's notes instead.
	var preset_notes := ""
	if is_tool_seeded:
		var base_preset: Dictionary = catalog._select_preset(event, str(preset.get("base_preset_id", "")))
		if base_preset.is_empty():
			return _error("The tool-seeded state's starting catalog preset is no longer available.")
		preset_notes = str(base_preset.get("notes", ""))
	else:
		preset_notes = str(preset.get("notes", ""))
	var reference := resolve_group_route_reference(event, preset_notes, profiles)
	if reference.is_empty():
		return _error("No analysis-group variant matches the requested preset.")
	var group_ref: Dictionary = reference.group_ref
	var route: Dictionary = reference.route
	var variant: Dictionary = reference.variant
	var verified: Dictionary = profiles.verify(group_ref)
	if not verified.get("ok", false):
		return _error(str(verified.get("error", "The analysis group profile changed.")))
	if not selection.is_empty() and not _selections_contain(variant, selection, route):
		return _error("The selected answer is not measured by this preset's variant; choose another preset.")
	# Round 2 code review (owner, 2026-09-20): the refusal of a tool-seeded
	# state that fails the route's own local guard belongs here, not only in
	# the Event Player UI - a caller can build and run a request without the
	# UI at all. A route without a guard (an unguarded/v9 route) skips the
	# check; nothing else about readiness_group changes.
	if is_tool_seeded and (route.get("guard", {}) as Dictionary).has("offset"):
		var guard_check := _tool_seeded_guard_check(documents, route, preset)
		if not guard_check.get("ok", false):
			return guard_check
	return {
		"ok": true, "event": event, "route": route, "variant": variant,
		"variant_id": str(variant.get("variant_id", "")), "variant_source": "named", "documents": documents,
		"schema": str(reference.get("schema", "")),
	}


## Seeds a route's runtime state exactly as `run_group_route` does: the
## route's own calendar context (when it declares `state_context.kind ==
## "original_calendar"`), built from the already-parsed `documents`, then
## `writes` loaded on top. The one seeding path `run_group_route`, the
## tool-seeded guard check and the Event Player's guard line all share, so
## what the guard line reports and what the service actually runs never
## disagree. `{"ok": true, "state": KakyuMesSandboxState}` or `{"ok": false, "error"}`.
func seed_route_state(documents: Dictionary, route: Dictionary, writes: Array) -> Dictionary:
	var seed := SandboxStateScript.new(1)
	var state_context: Dictionary = route.get("state_context", {})
	if str(state_context.get("kind", "")) == "original_calendar":
		var context_entry := str(state_context.get("entry", ""))
		if not documents.has(context_entry):
			return _error("The route's runtime calendar entry is not a declared dependency: %s" % context_entry)
		var projection: Dictionary = CalendarScript.new().build(documents[context_entry])
		if not projection.get("ok", false) or str(projection.get("table_sha256", "")) != str(state_context.get("table_sha256", "")):
			return _error("The route's source-bound runtime calendar context changed.")
		var applied := CalendarScript.new().apply_to_state(projection, seed)
		if not applied.get("ok", false):
			return _error("The route's runtime calendar context could not be applied.")
	var loaded := seed.load_values(writes)
	if not loaded.get("ok", false):
		return _error("The composed analysis-group preset contains an unsupported sandbox write.")
	return {"ok": true, "state": seed}


## Whether the tool-seeded preset's composed writes, seeded exactly as
## `run_group_route` would (`seed_route_state`), pass the route's local
## guard - run exactly as `KakyuEventGuardForm.guard_result` and
## `validate_event_analysis_group.gd`'s post-continuation guard check do:
## one instruction at `route.guard.offset` on the caller's bytecode.
func _tool_seeded_guard_check(documents: Dictionary, route: Dictionary, preset: Dictionary) -> Dictionary:
	var caller: Dictionary = route.get("caller", {})
	var caller_entry := str(caller.get("entry", ""))
	if not documents.has(caller_entry) or not (documents[caller_entry] as Dictionary).get("ok", false):
		return _error("The tool-seeded state's guard could not be evaluated: the caller could not be parsed.")
	var code: PackedByteArray = (documents[caller_entry] as Dictionary).get("bytecode", PackedByteArray())
	var guard: Dictionary = route.get("guard", {})
	var guard_offset := int(guard.get("offset", -1))
	var seeded := seed_route_state(documents, route, preset.get("writes", []))
	if not seeded.get("ok", false):
		return seeded
	var guard_result: Dictionary = GuardFormScript.guard_result(code, code.size(), guard_offset, seeded.state)
	if not guard_result.get("ok", false) or not guard_result.get("passes", false):
		return _error("The tool-seeded state does not pass the route's guard.")
	return {"ok": true}


## The row's route and variant, and the `analysis_group.groups[i]`
## reference that holds them - resolved from the preset itself, not by
## searching for a matching selection or terminal coordinate.
##
## Owner ruling (2026-09-20, round 6): a route id is not unique across a
## row's groups (the same route id can legitimately appear in more than one
## group, or under more than one profile version of the same group_id), so
## the preset - not a search - is the primary key of a run: its notes name
## `analysis-group variant <group_id>/<route_id>/<variant_id>`. Since a
## group_id can itself occur twice with different hashes, resolve the group
## by trying the row's own group references in order, taking the first
## whose id matches and whose profile (read by that reference's own hash)
## actually contains the named route and variant.
func resolve_group_route_reference(event: Dictionary, preset_notes: String, profiles) -> Dictionary:
	# Owner ruling (2026-09-20, round 7): the notes name the exact profile
	# too (`<group_id>@<hash12>/<route_id>/<variant_id>`, hash12 = the first
	# 12 hex characters of `profile_sha256`) - a group_id shared by more
	# than one profile hash (real data: ground-h17-k09 v1/v2) is
	# disambiguated by that prefix, not by trying every same-named group_id
	# reference until one happens to contain the route and variant.
	var prefix := "analysis-group variant "
	if not preset_notes.begins_with(prefix):
		return {}
	var parts := preset_notes.substr(prefix.length()).split("/")
	if parts.size() != 3:
		return {}
	var head := parts[0].split("@")
	if head.size() != 2:
		return {}
	var group_id := head[0]
	var hash12 := head[1]
	var route_id := parts[1]
	var variant_id := parts[2]
	for group_ref_value in event.get("analysis_group", {}).get("groups", []):
		var group_ref: Dictionary = group_ref_value
		if str(group_ref.get("group_id", "")) != group_id:
			continue
		if not str(group_ref.get("profile_sha256", "")).begins_with(hash12):
			continue
		var group_document: Dictionary = profiles.group(group_id, str(group_ref.get("profile_sha256", "")))
		if group_document.is_empty():
			continue
		var route := _find_route_in_document(group_document, route_id)
		if route.is_empty():
			continue
		var variant := _find_variant_in_route(route, variant_id)
		if variant.is_empty():
			continue
		return {
			"group_ref": group_ref, "route_id": route_id, "route": route, "variant": variant,
			"schema": str(group_document.get("schema", "")),
		}
	return {}


func _find_route_in_document(group_document: Dictionary, route_id: String) -> Dictionary:
	for route_value in group_document.get("routes", []):
		if str((route_value as Dictionary).get("route_id", "")) == route_id:
			return route_value
	return {}


func _find_variant_in_route(route: Dictionary, variant_id: String) -> Dictionary:
	for variant_value in route.get("variants", []):
		if str((variant_value as Dictionary).get("variant_id", "")) == variant_id:
			return variant_value
	# EP-11 part 1b: a visit preset's notes name the visit_id in the variant
	# slot (`promote_analysis_groups.py`'s `build_visit_presets`) - a v13
	# visit declares no `selections` of its own, so it stands in for a
	# variant with none; `variant_id` is aliased from `visit_id` so generic
	# readers of that key (e.g. `run_group_route`'s report) still resolve.
	for visit_value in route.get("visits", []):
		var visit: Dictionary = visit_value
		if str(visit.get("visit_id", "")) == variant_id:
			var stand_in := visit.duplicate(true)
			stand_in["variant_id"] = visit.get("visit_id", "")
			return stand_in
	return {}


func _selections_contain(variant: Dictionary, selection: Dictionary, route: Dictionary = {}) -> bool:
	# EP-12 catalog part (2026-09-24): a v14 flow route's own hops carry the
	# measured answers (`hop.answers`), not `variant.selections` - the owner is
	# the answering hop's own entry, not the route's callee. EP-12 (2026-10-04,
	# additive to v14): the variant may override a hop's answer or supply its
	# own (`variant.answers`), so what a variant measures is
	# `KakyuEventFlowRunner.hop_answers(hop, variant)` - the hop's own answers
	# for a variant that carries none (every installed flow route).
	if route.has("hops"):
		for untyped_hop in route.get("hops", []):
			var hop: Dictionary = untyped_hop
			var owner_entry := str(hop.get("entry", ""))
			for untyped_answer in FlowRunnerScript.hop_answers(hop, variant):
				var answer: Dictionary = untyped_answer
				if (
					owner_entry == str(selection.get("owner_entry", ""))
					and int(answer.get("boundary_offset", -1)) == int(selection.get("boundary_offset", -2))
					and int(answer.get("result_value", -1)) == int(selection.get("result_value", -2))
				):
					return true
		return false
	var route_callee := str(route.get("callee", {}).get("entry", ""))
	for selection_value in variant.get("selections", []):
		var candidate: Dictionary = selection_value
		var owner_entry := str(candidate.get("owner_entry", ""))
		if owner_entry.is_empty():
			owner_entry = route_callee
		if (
			owner_entry == str(selection.get("owner_entry", ""))
			and int(candidate.get("boundary_offset", -1)) == int(selection.get("boundary_offset", -2))
			and int(candidate.get("result_value", -1)) == int(selection.get("result_value", -2))
		):
			return true
	return false


## The descriptor `run_group_route` drives the caller-side probe with: the
## route's origin coordinate, the variant's choices, its map-location queues,
## and - when the route declares them - the root-handoff follow, loop
## detection and dispatch-stop boundaries. `{"ok": false, "error": ...}`
## when the route has no origin coordinate; otherwise the descriptor exactly
## as `run_group_route` builds it.
func build_group_route_descriptor(route: Dictionary, variant: Dictionary) -> Dictionary:
	var caller: Dictionary = route.caller
	var callee: Dictionary = route.callee
	var choices: Array = []
	for selection_value in variant.get("selections", []):
		var selection_entry: Dictionary = selection_value
		var owner_entry := str(selection_entry.get("owner_entry", ""))
		if owner_entry.is_empty():
			owner_entry = str(route.get("callee", {}).get("entry", ""))
		choices.append({
			"owner_entry": owner_entry,
			"boundary_offset": int(selection_entry.boundary_offset),
			"options": [{"result_value": int(selection_entry.result_value)}],
		})
	var map_locations := ProbeScript.map_location_queues(route.get("map_location_contracts", []))
	var origin := -1
	if route.has("origin_offset"):
		origin = int(route.origin_offset)
	elif route.has("guard") and (route.guard as Dictionary).has("offset"):
		origin = int(route.guard.offset)
	if origin < 0:
		return {"ok": false, "error": "The route has no origin coordinate."}
	var descriptor := {
		"ok": true,
		"entry": str(caller.entry), "start_coordinate": origin,
		"choices": choices, "map_locations": map_locations,
	}
	if str(route.get("caller_outcome", {}).get("kind", "")) == "root_handoff":
		descriptor["follow_root_handoff"] = {
			"entry": str(caller.entry), "offset": int(caller.offset), "end": int(caller.end), "target": str(callee.entry),
		}
	if str(route.get("resume", {}).get("boundary_policy", "")) == "caller_menu_loop":
		descriptor["detect_loops"] = true
	if str(route.get("resume", {}).get("boundary_policy", "")) == "stop_before_unprovided_dependency":
		var resume_outcome: Dictionary = route.resume.get("outcome", {})
		descriptor["stop_before_dispatch"] = {
			"entry": str(caller.entry), "offset": int(resume_outcome.get("offset", -1)),
			"end": int(resume_outcome.get("end", -1)), "target": str(resume_outcome.get("target", "")),
		}
	return descriptor


func run_group_route(reader, resolver, catalog, profiles, request: Dictionary) -> Dictionary:
	var checked := readiness_group(reader, resolver, catalog, profiles, request)
	if not checked.get("ok", false):
		return checked
	var event: Dictionary = checked.event
	var route: Dictionary = checked.route
	var variant: Dictionary = checked.variant
	var variant_source: String = str(checked.variant_source)
	# Round 3 code review, item 5: `readiness_group` already parsed every
	# member document; reuse it instead of re-reading and re-parsing the
	# same entries.
	var documents: Dictionary = checked.documents
	var probe := ProbeScript.new()
	var provider := probe.context_from_documents(documents)
	if not provider.get("ok", false):
		return provider
	if str(checked.get("schema", "")) == FLOW_SCHEMA:
		return _run_group_flow_route(catalog, event, route, variant, variant_source, probe, provider, documents, request)
	var seeded := seed_route_state(documents, route, request.preset.get("writes", []))
	if not seeded.get("ok", false):
		return seeded
	var seed: KakyuMesSandboxState = seeded.state
	var descriptor := build_group_route_descriptor(route, variant)
	if not descriptor.get("ok", false):
		return _error(str(descriptor.get("error", "The route has no origin coordinate.")))
	var result := probe.run_route(provider, descriptor, {}, seed)
	if not result.get("ok", false):
		return _error(str(result.get("error", "The group route could not be run.")))
	var event_id := str(event.event_id)
	var selection: Dictionary = request.get("selection", {})
	var terminal_match: Dictionary
	if not str(result.get("stop", "")).is_empty():
		var stop_detail: Dictionary = result.get("stop_detail", {})
		var trace: Array = result.get("trace", [])
		var last_trace: Dictionary = trace[-1] if not trace.is_empty() else {}
		var def_selection_stop := int(last_trace.get("routine_id", -1)) == 40
		var candidate_terminal_ids: Array = []
		if not selection.is_empty():
			candidate_terminal_ids = selection.get("terminal_ids", [])
		else:
			for terminal_value in event.get("terminals", []):
				candidate_terminal_ids.append(str((terminal_value as Dictionary).terminal_id))
		var contract: Dictionary = catalog.build_terminal_contract(event_id)
		var matched_stage: Dictionary = {}
		if contract.get("ok", false):
			for stage_value in contract.get("stages", []):
				var stage: Dictionary = stage_value
				if not (candidate_terminal_ids.has(str(stage.terminal_id)) and str(stage.kind) == "analysis_boundary"):
					continue
				var status := str(stage.runtime_status)
				# A dependency stop the descriptor's `stop_before_dispatch`
				# requested: the probe's stop_detail carries the exact
				# owner/offset. A def-selection boundary the routine-40
				# consumer stops at because the row supplies no choice there
				# (the same coordinate `validate_event_analysis_group.gd`'s
				# `_observation` reads from the trace's last row, not
				# `stop_detail`, which carries no coordinate for this stop).
				if status == "script_dispatch_boundary":
					if (
						str(stage.owner_entry).to_upper() == str(stop_detail.get("entry", "")).to_upper()
						and int(stage.offset) == int(stop_detail.get("offset", -2))
					):
						matched_stage = stage
						break
				elif status == "def_selection_boundary" and def_selection_stop:
					if (
						str(stage.owner_entry).to_upper() == str(last_trace.get("source_entry", "")).to_upper()
						and int(stage.offset) == int(last_trace.get("source_offset", -2))
					):
						matched_stage = stage
						break
		if matched_stage.is_empty():
			return _error("The group route stopped: %s" % str(result.get("stop", "unknown")))
		terminal_match = matched_stage.duplicate(true)
		terminal_match["ok"] = true
	else:
		terminal_match = catalog.match_terminal(event_id, {
			"owner_entry": str(result.terminal.get("entry", "")), "runtime_status": str(result.terminal.get("status", "")),
			"offset": int(result.terminal.get("offset", -1)), "next_target": str(result.terminal.get("target", "")),
			"state_values": result.state,
		})
		if not terminal_match.get("ok", false):
			return _error("The group route did not reach a cataloged terminal.")
		if not selection.is_empty() and not (selection.get("terminal_ids", []) as Array).has(str(terminal_match.terminal_id)):
			return _error("The group route reached a terminal outside the selected option.")
	return {
		"ok": true, "probe": result, "terminal_match": terminal_match, "complete": true,
		"scope": "group_route_unbroken_caller_path", "caller_executed": true, "native_presentation": "omitted",
		"route_id": str(route.route_id), "variant_id": str(variant.get("variant_id", "")), "variant_source": variant_source,
		"preset_id": str(request.preset.preset_id),
		"state_origin": "tool_seeded" if (request.get("preset", {}) as Dictionary).has("base_preset_id") else "catalog_preset",
	}


## EP-12 catalog part: `run_group_route`'s own v14 branch. A flow route has
## no per-route `caller`/`callee` pair or `origin_offset` for
## `build_group_route_descriptor`, so this runs `KakyuEventFlowRunner`
## instead over the whole hop chain and matches the last hop's own natural
## terminal against the catalog exactly as the v8/v9 path matches
## `probe.run_route`'s own terminal - `catalog.match_terminal` does not
## distinguish where its `observation` came from.
func _run_group_flow_route(
	catalog, event: Dictionary, route: Dictionary, variant: Dictionary, variant_source: String,
	probe: KakyuMesRouteProbe, provider: Dictionary, documents: Dictionary, request: Dictionary,
) -> Dictionary:
	var result := FlowRunnerScript.run_route(probe, provider, documents, route, variant, {})
	if not result.get("ok", false):
		return _error("The group route could not be run: %s" % ", ".join(result.get("failures", []) as Array))
	var event_id := str(event.event_id)
	var selection: Dictionary = request.get("selection", {})
	var terminal: Dictionary = result.terminal
	var terminal_match: Dictionary = catalog.match_terminal(event_id, {
		"owner_entry": str(terminal.get("entry", "")), "runtime_status": str(terminal.get("status", "")),
		"offset": int(terminal.get("offset", -1)), "next_target": str(terminal.get("target", "")),
		"state_values": result.state,
	})
	if not terminal_match.get("ok", false):
		return _error("The group route did not reach a cataloged terminal.")
	if not selection.is_empty() and not (selection.get("terminal_ids", []) as Array).has(str(terminal_match.terminal_id)):
		return _error("The group route reached a terminal outside the selected option.")
	return {
		"ok": true, "probe": result, "terminal_match": terminal_match, "complete": true,
		"scope": "group_route_unbroken_caller_path", "caller_executed": true, "native_presentation": "omitted",
		"route_id": str(route.route_id), "variant_id": str(variant.get("variant_id", "")), "variant_source": variant_source,
		"preset_id": str(request.preset.preset_id),
		"state_origin": "tool_seeded" if (request.get("preset", {}) as Dictionary).has("base_preset_id") else "catalog_preset",
	}


## The preset id whose state was actually measured for the given option:
## the first catalog preset (in the row's own order) whose named variant's
## `selections` contain the option's selection (an owner-less selection
## defaulting to that variant's own route's callee) - or, for a choiceless
## row, the row's first preset. `""` when none resolves (an unknown
## event/option, or a row with no presets). Pure catalog and profile lookup
## - no archive access, safe to call before one is open.
func pick_measured_preset_id(catalog, profiles, event_id: String, option_id: String) -> String:
	var event: Dictionary = catalog.get_event(event_id)
	if not event.has("analysis_group"):
		return ""
	var probe_request: Dictionary = catalog.build_play_request(event_id, "", option_id)
	if not probe_request.get("ok", false):
		return ""
	var selection: Dictionary = probe_request.get("selection", {})
	var presets: Array = event.get("presets", [])
	if selection.is_empty():
		return str((presets[0] as Dictionary).get("preset_id", "")) if not presets.is_empty() else ""
	for preset_value in presets:
		var preset: Dictionary = preset_value
		var reference := resolve_group_route_reference(event, str(preset.get("notes", "")), profiles)
		if reference.is_empty():
			continue
		if _selections_contain(reference.variant, selection, reference.route):
			return str(preset.get("preset_id", ""))
	return ""


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
