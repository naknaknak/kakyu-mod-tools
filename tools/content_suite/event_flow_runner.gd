class_name KakyuEventFlowRunner
extends RefCounted

## EP-12 catalog part (2026-09-24): the v14 flow shape's hop-chain runner,
## extracted from `event_analysis_group_flow_validation.gd`'s own
## `_run_route`/`_seed_flow_state` (TD-05: `catalog_analysis_run.gd` needed
## the same chaining to run a promoted flow row's route, and the rule is a
## shared helper rather than a second copy). Lives under
## `tools/content_suite/` rather than `content_core/`: both importers -
## the flow validator and the catalog run - are Content Suite tools: the
## Event Player never needs it at runtime because `catalog_analysis_run.gd`
## is itself a tool script the player only calls into for analysis, not a
## `content_core/` runtime dependency.
##
## The mechanics (seeding order, per-hop coordinate stepping, tool-seeded
## gate writes, request building, the `probe.run_route` calls, and the
## combined trace/messages/state) live here so there is exactly one
## implementation. Whether a hop's outcome, message count or expected state
## actually matches the profile's own `expected` block - and the guard
## witness replay, which never calls `probe.run_route` at all - stays the
## caller's own assertion, in its own wording, over the raw data this
## returns.

const State := preload("res://content_core/mes_sandbox_state.gd")
const Calendar := preload("res://content_core/mes_calendar_state.gd")
const Probe := preload("res://content_core/mes_route_probe.gd")


## Seeds a flow route's runtime state exactly as
## `event_analysis_group_flow_validation.gd`'s own `_seed_flow_state` did
## before this was extracted: `route.state_context` (an `original_calendar`
## context built from `documents`) applied first, then `route.baseline`,
## then `writes`, loaded on top. `{"ok", "state": KakyuMesSandboxState,
## "checks": [{"label", "ok"}]}` - `checks` names each assertion a caller
## still runs through its own `_check` accounting, in the exact wording used
## before extraction ("source-bound runtime calendar context",
## "route witness state"), so a caller's check count does not move.
static func seed_flow_state(route: Dictionary, writes: Array, documents: Dictionary) -> Dictionary:
	var seed := State.new(1)
	var checks: Array[Dictionary] = []
	var context: Dictionary = route.get("state_context", {"kind": "fresh"})
	if str(context.get("kind", "")) == "original_calendar":
		var calendar := Calendar.new()
		var projection := calendar.build(documents[context.entry])
		var calendar_ok: bool = (
			projection.get("ok", false) and projection.get("table_sha256") == context.table_sha256
			and calendar.apply_to_state(projection, seed).get("ok", false)
		)
		checks.append({"label": "source-bound runtime calendar context", "ok": calendar_ok})
	var loaded_ok: bool = seed.load_values(route.get("baseline", [])).get("ok", false) and seed.load_values(writes).get("ok", false)
	checks.append({"label": "route witness state", "ok": loaded_ok})
	var all_ok := true
	for check in checks:
		if not bool(check.ok):
			all_ok = false
	return {"ok": all_ok, "state": seed, "checks": checks}


## The routine-40 answers a `variant` gives at `hop` (EP-12, 2026-10-04,
## additive to v14): the hop's own `answers`, each one whose boundary the
## variant's `answers` names for this hop (`{hop_id, boundary_offset,
## result_value}`) replaced by the variant's value, then any variant answer
## the hop has no answer for at that boundary appended. A variant with no
## `answers` (or none naming this hop) returns the hop's own answers
## unchanged, so every profile that predates the field runs as before. Returns
## `[{boundary_offset, result_value}]`, the shape a hop's `answers` already
## has; the one place the override rule lives (`run_route` and
## `catalog_analysis_run.gd`'s `_selections_contain` both call it).
static func hop_answers(hop: Dictionary, variant: Dictionary) -> Array:
	var hop_id := str(hop.get("hop_id", ""))
	var overrides := {}
	for untyped_variant_answer in variant.get("answers", []):
		var variant_answer: Dictionary = untyped_variant_answer
		if str(variant_answer.get("hop_id", "")) == hop_id:
			overrides[int(variant_answer.boundary_offset)] = int(variant_answer.result_value)
	var answers: Array = []
	for untyped_answer in hop.get("answers", []):
		var answer: Dictionary = untyped_answer
		var boundary := int(answer.boundary_offset)
		if overrides.has(boundary):
			answers.append({"boundary_offset": boundary, "result_value": int(overrides[boundary])})
			overrides.erase(boundary)
		else:
			answers.append({"boundary_offset": boundary, "result_value": int(answer.result_value)})
	for boundary in overrides:
		answers.append({"boundary_offset": int(boundary), "result_value": int(overrides[boundary])})
	return answers


## The message count a `variant` plays at `hop` (EP-12, 2026-10-04, additive
## to v14): `variant.message_counts[hop_id]` when the variant names the hop,
## else the hop's own `expected.message_count`. The flow validator asserts
## this, not the hop's count alone, for every variant.
static func hop_message_count(hop: Dictionary, variant: Dictionary) -> int:
	var counts: Dictionary = variant.get("message_counts", {})
	var hop_id := str(hop.get("hop_id", ""))
	if counts.has(hop_id):
		return int(counts[hop_id])
	return int((hop.get("expected", {}) as Dictionary).get("message_count", 0))


## Walks `route.hops` from `route.origin.offset` for one `variant`. A hop's
## routine-40 answers are `hop_answers(hop, variant)`: the hop's own, with the
## variant's overrides applied. Coordinate
## stepping: hop 0 starts at the origin; a later hop whose own
## `entered_by.kind` is "resume" starts at the previous hop's own
## `entered_by.end` (the resuming script's own return point - what the
## dispatch hop before it recorded, not a coordinate the resume hop names
## itself); any other later hop (a nested call or a root handoff) starts at
## offset 0 of its own entry. A hop's `gates` with `basis == "tool_seeded"`
## are written directly into the carried state before the hop runs; any
## other gate is only read here (`gate_reads`), so the caller can still judge
## whether it holds in its own wording. `options.writes` overrides
## `variant.writes` when supplied (a tool-seeded run); otherwise the variant's
## own measured writes are used, exactly as before extraction. `options.initial_state`
## (a `KakyuMesSandboxState`) skips `seed_flow_state` entirely and starts the
## walk from that state instead - the playback-package comparison
## (`validate_playback_package_playback.gd`) seeds once, from the reference
## archive's own documents, and runs the same seeded state through both the
## reference and the packaged code source, exactly as it already does for a
## v8/v9 route's single `probe.run_route` call.
##
## Returns `{ok, failures, seed_checks, hops:[{hop_id, entry,
## start_coordinate, run, gate_reads:[{gate, actual}]}], trace, messages,
## segments, rows, library_media, signature, message_hex, stop, stop_detail,
## state, state_object, state_diff, terminal}`. `trace`/`messages`/`segments`/
## `rows`/`message_hex` are every hop's own run concatenated in hop order;
## `library_media` is every hop's own `library_media` (EP-14, Core 0.378.0) in
## hop order too, each row copied and its `trace_index` offset by the combined
## `trace`'s length before that hop's rows were appended, so it indexes the
## combined `trace` exactly as one hop's list indexes its own (a hop report's
## own `run.library_media` keeps its hop-local indices);
## `signature` is `probe.run_route`'s own convention (the SHA-256 of the
## combined `rows`, stringified) so a caller compares a whole flow's trace
## the same way it compares one ordinary route's. `state_object`/`state_diff`
## are the carried sandbox state after the last hop and its diff from the
## seeded start. `terminal`/`stop`/`stop_detail` are the last hop's own
## `run` values - the natural `script_handoff_boundary` record for a
## completed flow, with `target` - which `catalog.match_terminal` reads
## exactly as for any other row's terminal. `failures` names only a break in
## the chain's own mechanics (an unknown package member); it is empty for a
## well-formed route. `seed_checks` is `seed_flow_state`'s own return (empty
## when `options.initial_state` was used instead), for the caller to run
## through `_check`.
static func run_route(probe: KakyuMesRouteProbe, provider: Dictionary, documents: Dictionary, route: Dictionary, variant: Dictionary, options: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = []
	var origin: Dictionary = route.get("origin", {})
	var origin_entry := str(origin.get("entry", ""))
	var seed_checks: Array = []
	var run_state: KakyuMesSandboxState = options.get("initial_state", null)
	if run_state == null:
		var writes: Array = options.get("writes", variant.get("writes", []))
		var seeded := seed_flow_state(route, writes, documents)
		run_state = seeded.state
		seed_checks = seeded.checks
	var before := run_state.snapshot()
	var coordinate: int = int(origin.get("offset", -1))
	var current_entry := origin_entry
	var hops: Array = route.get("hops", [])
	var hop_reports: Array = []
	var combined_trace: Array = []
	var combined_messages: Array = []
	var combined_segments: Array = []
	var combined_rows: Array = []
	var combined_library_media: Array = []
	var combined_message_hex: Array = []
	for index in range(hops.size()):
		var hop: Dictionary = hops[index]
		if index > 0:
			var entered_by: Dictionary = hop.get("entered_by", {})
			if str(entered_by.get("kind", "")) == "resume":
				coordinate = int(((hops[index - 1] as Dictionary).get("entered_by", {}) as Dictionary).get("end", -1))
			else:
				coordinate = 0
			current_entry = str(hop.get("entry", ""))
		var gate_reads: Array = []
		for untyped_gate in hop.get("gates", []):
			var gate: Dictionary = untyped_gate
			if str(gate.get("basis", "")) == "tool_seeded":
				run_state.write_value(str(gate.storage), int(gate.index), int(gate.value), int(gate.get("bank", 0)))
			else:
				gate_reads.append({"gate": gate, "actual": run_state.read_value(str(gate.storage), int(gate.index), int(gate.get("bank", 0)))})
		var choices := []
		for untyped_answer in hop_answers(hop, variant):
			var answer: Dictionary = untyped_answer
			choices.append({
				"owner_entry": current_entry, "boundary_offset": int(answer.boundary_offset),
				"options": [{"result_value": int(answer.result_value)}],
			})
		var expected: Dictionary = hop.get("expected", {})
		var outcome: Dictionary = expected.get("outcome", {})
		var request := {
			"entry": current_entry, "start_coordinate": coordinate, "choices": choices,
			"map_locations": Probe.map_location_queues(hop.get("map_locations", [])),
			"poll_supplies": hop.get("poll_supplies", []),
		}
		# EP-12 H (2026-10-04, additive to v14): a hop that declares a
		# `segment_budget` asks the probe for that many segments (default 512);
		# a hop without one makes the request it always made.
		if hop.has("segment_budget"):
			request["segment_budget"] = hop.segment_budget
		if str(outcome.get("status", "")) == "script_dispatch_boundary":
			request["stop_before_dispatch"] = {
				"entry": current_entry, "offset": int(outcome.offset),
				"end": int(outcome.end), "target": str(outcome.get("target", "")),
			}
		if not (provider.get("entries", {}) as Dictionary).has(current_entry):
			failures.append("%s is not a package member" % current_entry)
			break
		var run := probe.run_route(provider, request, {}, run_state)
		hop_reports.append({
			"hop_id": str(hop.get("hop_id", "")), "entry": current_entry,
			"start_coordinate": coordinate, "run": run, "gate_reads": gate_reads,
		})
		# EP-14: copy each row before offsetting it; the hop report above keeps this
		# very run, and an in-place offset would rewrite its hop-local indices.
		for untyped_media in run.get("library_media", []):
			var media: Dictionary = (untyped_media as Dictionary).duplicate(true)
			media["trace_index"] = int(media.get("trace_index", -1)) + combined_trace.size()
			combined_library_media.append(media)
		combined_trace.append_array(run.get("trace", []))
		combined_messages.append_array(run.get("messages", []))
		combined_segments.append_array(run.get("segments", []))
		combined_rows.append_array(run.get("rows", []))
		combined_message_hex.append_array(run.get("message_hex", []))
		run_state = run.get("state_object", run_state)
	var last_run: Dictionary = (hop_reports[-1] as Dictionary).get("run", {}) if not hop_reports.is_empty() else {}
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"seed_checks": seed_checks,
		"hops": hop_reports,
		"trace": combined_trace,
		"messages": combined_messages,
		"segments": combined_segments,
		"rows": combined_rows,
		"library_media": combined_library_media,
		"signature": JSON.stringify(combined_rows).sha256_text(),
		"message_hex": combined_message_hex,
		"stop": str(last_run.get("stop", "")),
		"stop_detail": last_run.get("stop_detail", {}),
		"state": run_state.to_records(),
		"state_object": run_state,
		"state_diff": run_state.diff(before),
		"terminal": last_run.get("terminal", {}),
	}
