class_name KakyuMesRouteProbe
extends RefCounted

# A bounded analysis instrument shared by package equivalence and contextual
# edited-event verification. It is not the mod player's presentation runtime.
const LibraryIndexScript := preload("res://content_core/mes_library_index.gd")
const StartupContextScript := preload("res://content_core/mes_startup_context.gd")
const RunnerScript := preload("res://content_core/mes_event_runner.gd")
const LibraryRunnerScript := preload("res://content_core/mes_library_runner.gd")
const ChoiceContractScript := preload("res://content_core/mes_routine40_choice_contract.gd")
const DefinitionCallScript := preload("res://content_core/mes_registered_definition_call.gd")
const StateScript := preload("res://content_core/mes_sandbox_state.gd")
const LIBRARY_ENTRY := "LIBLARY.LIB"
const DEFINITION_ENTRY := "DEF_MAIN.MES"
const PROVENANCE_COMMANDS := {0x1F: true, 0x17: true, 0xFF: true}
## The five trace effects `mes_event_runner.gd` emits for a media request: the
## MMO marker (`_apply_mmo_marker`), `ax_resource_marker`, `voice_marker`,
## `effect_request` (a sound effect) and `bgm_request` (the routine-23 transfer).
## One list for every consumer that selects media rows by effect: this probe's
## `library_media` (EP-14), the Playback timeline's validation of it and
## `replay_run_media.gd`'s `resource_rows`.
const MEDIA_EFFECTS := ["mmo_resource_marker", "ax_resource_marker", "voice_marker", "effect_request", "bgm_request"]
## Segments one script frame may spend before the walk stops with "segment
## limit reached". A route descriptor may raise it with `segment_budget` (EP-12
## H, 2026-10-04): a v14 hop that declares one asks for more, nothing else
## changes - the default is what every earlier measurement was made under.
const DEFAULT_SEGMENT_BUDGET := 512


## The `map_locations` descriptor queues for a route's own
## `map_location_contracts` - fresh, independent queues (`run_route`
## consumes each in place): `{entry, poll_offset, result_storage,
## result_index, values}` per contract. Shared by
## `catalog_analysis_run.gd`'s `run_group_route` and
## `validate_event_analysis_group.gd`'s `_map_locations`.
static func map_location_queues(contracts: Array) -> Array:
	var queues := []
	for untyped_contract in contracts:
		var contract: Dictionary = untyped_contract
		queues.append({
			"entry": str(contract.source_identity.entry), "poll_offset": int(contract.poll_offset),
			"result_storage": str(contract.result_storage), "result_index": int(contract.result_index),
			"values": (contract.locations as Array).duplicate(),
		})
	return queues


func run_route(provider: Dictionary, descriptor: Dictionary, selected_preset: Dictionary = {}, initial_state: KakyuMesSandboxState = null) -> Dictionary:
	var run_state := {
		"state": StateScript.new(1) if initial_state == null else initial_state.duplicate_state(),
		"segments": [] as Array[Dictionary],
		"rows": [] as Array[Dictionary],
		"message_hex": [] as Array[String],
		"trace": [] as Array[Dictionary],
		"library_media": [] as Array[Dictionary],
		"messages": [] as Array[Dictionary],
		"terminal": {},
		"descriptor": descriptor,
	}
	# Presets overlay a private clone of the supplied runtime state (or a fresh
	# sandbox). Do not serialize a calendar-backed continuation through records:
	# its relative-byte baseline and alias policy are deliberately runtime-only.
	var presets: Array = descriptor.get("presets", [])
	var preset: Dictionary = selected_preset if not selected_preset.is_empty() else (presets[0] if not presets.is_empty() else {})
	var loaded: Dictionary = run_state.state.load_values(preset.get("writes", []))
	if not loaded.get("ok", false):
		return {"ok": false, "error": "Route preset contains an invalid state write."}
	var before: Dictionary = run_state.state.snapshot()
	# 0.318.0: map-location contracts. Each names an entry, the Map.get_location
	# poll record and the locations to supply there, in order; the queue is one
	# object shared by every frame of this run so consumption carries across
	# segments and nested calls, and the result reports what remains.
	var map_locations := []
	for untyped_contract in descriptor.get("map_locations", []):
		var contract: Dictionary = untyped_contract
		map_locations.append({"entry": str(contract.get("entry", "")).to_upper(),
			"poll_offset": int(contract.get("poll_offset", -1)),
			"result_storage": str(contract.get("result_storage", "state_u16")),
			"result_index": int(contract.get("result_index", 18)),
			"values": (contract.get("values", []) as Array).duplicate()})
	run_state["map_locations"] = map_locations
	# EP-12 (2026-09-24, tool decision): a `poll_supplies` descriptor names
	# a registered definition (by id) and one plain-state cell to write,
	# every time the definition's own poll branch is reached - the same
	# seam as `map_locations`, generalised only as far as a wait loop
	# inside a `definition_invoke` needs (see `_run_definition` and
	# `mes_event_runner.gd`'s own `_supplied_poll`).
	var poll_supplies := []
	for untyped_supply in descriptor.get("poll_supplies", []):
		var supply: Dictionary = untyped_supply
		poll_supplies.append({"definition": int(supply.get("definition", -1)),
			"poll_offset": int(supply.get("poll_offset", -1)),
			"result_storage": str(supply.get("result_storage", "state_u16")),
			"result_index": int(supply.get("result_index", 18)),
			"value": int(supply.get("value", 0))})
	run_state["poll_supplies"] = poll_supplies
	# EP-12 H (2026-10-04, tool decision): `segment_budget` raises the per-frame
	# segment budget of this run (default 512). A whole-number JSON value arrives
	# as a float, so a float with no fraction is accepted; anything else - a
	# string, a bool, zero, a negative or fractional number - is refused.
	var budget_value: Variant = descriptor.get("segment_budget", DEFAULT_SEGMENT_BUDGET)
	var budget_type := typeof(budget_value)
	if not (budget_type == TYPE_INT or budget_type == TYPE_FLOAT) or float(budget_value) != floorf(float(budget_value)) \
			or float(budget_value) < 1.0:
		return {"ok": false, "error": "invalid segment budget"}
	run_state["segment_budget"] = int(budget_value)
	var entry := str(descriptor.entry)
	var walked := {"ok": false, "error": "%s is not a package member" % entry}
	if provider.entries.has(entry):
		walked = _walk(provider, run_state, entry, int(descriptor.start_coordinate), 0)
	return {
		"ok": true,
		"segments": run_state.segments,
		"rows": run_state.rows,
		"signature": JSON.stringify(run_state.rows).sha256_text(),
		"message_hex": run_state.message_hex,
		"state": run_state.state.to_records(),
		"state_object": run_state.state,
		"state_diff": run_state.state.diff(before),
		"trace": run_state.trace,
		"library_media": run_state.library_media,
		"messages": run_state.messages,
		"terminal": run_state.terminal,
		"stop": "" if bool(walked.get("ok", false)) else str(walked.get("error", "stopped")),
		"stop_detail": {} if bool(walked.get("ok", false)) else walked.duplicate(true),
		"map_locations": run_state.map_locations,
		"map_locations_remaining": _map_locations_remaining(run_state),
	}


func _walk(
	provider: Dictionary,
	run_state: Dictionary,
	entry: String,
	start_offset: int,
	depth: int
) -> Dictionary:
	if depth > 2:
		return {"ok": false, "error": "nested call depth exceeded"}
	var binding: Dictionary = provider.entries[entry]
	var state: KakyuMesSandboxState = run_state.state
	var context := {
		"native_record_policy": "omit_bounded",
		"address_table_offsets": (binding.address_table as Array).duplicate(),
		"protagonist_name": "Audit",
	}
	if binding.source != null:
		context["code_source"] = binding.source
	context["map_locations"] = _map_locations_for(run_state, entry)
	var cursor := start_offset
	# 0.317.0: a route may ask the probe to prove a loop instead of spending
	# its segment budget in one. A continuation is (entry, boundary record,
	# stored values, RNG position, argument slots, persistent expression
	# stack); the runner is deterministic, so a continuation seen twice
	# repeats forever. The walk then stops at the first occurrence - the loop
	# head - keeps only what was collected up to it, and reports the cycle.
	var detect_loops: bool = bool(run_state.descriptor.get("detect_loops", false))
	var seen := {}
	for _segment in range(int(run_state.segment_budget)):
		var result := RunnerScript.new().run(
			binding.code, cursor, state, int(binding.code_size), 10000, context
		)
		context["argument_slots"] = result.get("argument_slots", {}).duplicate(true)
		context["persistent_expression_stack"] = result.get(
			"persistent_expression_stack", []
		).duplicate()
		_collect(run_state, entry, result)
		var trace: Array = result.get("trace", [])
		var terminal_row: Dictionary = trace[-1] if not trace.is_empty() else {}
		var status := str(result.status)
		run_state.segments.append({
			"entry": entry,
			"status": status,
			"offset": int(result.offset),
			"resume": int(result.get("resume_offset", -1)),
		})
		if detect_loops and not status in ["script_return", "script_handoff_boundary"]:
			var key := _continuation_key(entry, int(result.offset), state, context)
			if seen.has(key):
				return _loop_boundary(run_state, entry, seen[key])
			seen[key] = {"segment": run_state.segments.size() - 1, "rows": run_state.rows.size(),
				"trace": run_state.trace.size(), "library_media": run_state.library_media.size(),
				"messages": run_state.messages.size(),
				"message_hex": run_state.message_hex.size(), "end": int(terminal_row.get("end_offset", -1))}
		match status:
			"dialogue_boundary":
				cursor = int(result.get("resume_offset", -1))
			"native_presentation_boundary":
				# The runner stops where a native single-byte stream begins; the
				# export resolved where that stream ends, so playback continues
				# after it without reinterpreting its payload.
				var probe: Dictionary = terminal_row.get("native_stream_probe", {})
				var stream_end := int(probe.get("probe_end_offset", -1))
				if stream_end <= int(result.offset) or stream_end > int(binding.code_size):
					return {"ok": false, "error": "native stream end is outside %s" % entry}
				cursor = stream_end
			"shared_routine_boundary":
				var routine := int(terminal_row.get("routine_id", -1))
				# EP-14: the shared-call record's code-relative offset in this
				# entry is the MES-anchored coordinate of every medium the
				# routine presents (`library_media`).
				var caller := {"caller_entry": entry, "caller_offset": int(terminal_row.get("source_offset", -1)),
					"caller_definition_id": -1}
				var library := _run_library(provider, run_state, routine, context, caller)
				if not library.get("ok", false):
					return library
				context["argument_slots"] = library.argument_slots
				context["persistent_expression_stack"] = library.persistent_expression_stack
				cursor = int(result.get("resume_offset", -1))
			"def_selection_boundary":
				var chosen := _select_choice(provider, run_state, entry, binding, result)
				if not chosen.get("ok", false):
					return chosen
				run_state.segments.append({
					"entry": entry,
					"status": "choice_selected",
					"offset": int(chosen.boundary_offset),
					"resume": int(chosen.resume_offset),
				})
				cursor = int(chosen.resume_offset)
			"definition_invoke_boundary":
				var invoked := _run_definition(provider, run_state, terminal_row, context)
				if not invoked.get("ok", false):
					return invoked
				context["argument_slots"] = invoked.argument_slots
				context["persistent_expression_stack"] = invoked.persistent_expression_stack
				cursor = int(result.get("resume_offset", -1))
			"script_dispatch_boundary":
				var target := str(terminal_row.get("target_entry", "")).to_upper()
				# A coordinate-bound analysis stop can inspect a later call to a
				# member that earlier calls must still execute. Keep the dispatch
				# trace and carried state, but do not invoke the selected child.
				var requested: Dictionary = run_state.descriptor.get("stop_before_dispatch", {})
				if requested.get("entry", "") == entry and requested.get("offset", -1) == result.offset:
					var exact: bool = requested.get("end", -1) == terminal_row.get("end_offset", -2) and requested.get("target", "") == target
					return {"ok":false, "error":"analysis dispatch stop" if exact else "analysis dispatch stop identity differs",
						"status":"analysis_dispatch_stop" if exact else "analysis_dispatch_mismatch", "entry":entry,
						"offset":int(result.offset), "end":int(terminal_row.get("end_offset", -1)), "target":target}
				if not provider.entries.has(target):
					return {"ok": false, "error": "nested entry %s is not a package member" % target}
				var nested := _walk(provider, run_state, target, 0, depth + 1)
				# A root replacement terminates every suspended script frame, and
				# so does a proven loop. Only an ordinary nested return may
				# execute the caller suffix.
				if not nested.get("ok", false) or nested.get("handoff", false) or nested.get("loop", false):
					return nested
				cursor = int(result.get("resume_offset", -1))
			"script_return":
				if depth > 0:
					return {"ok": true}
				run_state.terminal = {
					"entry": entry,
					"status": status,
					"offset": int(result.offset),
					"end": int(terminal_row.get("end_offset", -1)),
					"target": "",
				}
				return {"ok": true}
			"script_handoff_boundary":
				run_state.terminal = {
					"entry": entry,
					"status": status,
					"offset": int(result.offset),
					"end": int(terminal_row.get("end_offset", -1)),
					"target": str(terminal_row.get("target_entry", "")).to_upper(),
				}
				# Analysis may follow one exact root replacement. Consume it once
				# so a target that revisits this coordinate still stops boundedly.
				var requested: Dictionary = run_state.descriptor.get("follow_root_handoff", {})
				if not run_state.get("root_handoff_followed", false) and requested.get("entry", "") == entry and requested.get("offset", -1) == result.offset:
					if requested.get("end", -1) != run_state.terminal.end or requested.get("target", "") != run_state.terminal.target:
						return {"ok":false,"error":"analysis root handoff identity differs","status":"analysis_handoff_mismatch"}
					var target: String = run_state.terminal.target
					if not provider.entries.has(target):
						return {"ok":false,"error":"root entry %s is not a package member" % target}
					run_state["root_handoff_followed"] = true
					run_state.terminal = {}
					# Keep sandbox state, but start a new root frame and its own
					# temporary context. No suspended caller can resume afterwards.
					var replacement := _walk(provider, run_state, target, 0, 0)
					replacement["handoff"] = true
					return replacement
				return {"ok": true, "handoff": true}
			_:
				return {
					"ok": false,
					"error": "%s at 0x%X in %s" % [status, int(result.offset), entry],
				}
		if cursor < 0:
			return {"ok": false, "error": "boundary exposed no resume coordinate in %s" % entry}
	return {"ok": false, "error": "segment limit reached in %s" % entry}


func _continuation_key(entry: String, offset: int, state: KakyuMesSandboxState, context: Dictionary) -> String:
	# The remaining map locations are part of the future too.
	var parts := [entry, offset, state.snapshot(), context.get("argument_slots", {}),
		context.get("persistent_expression_stack", []), state.random_state(), context.get("map_locations", [])]
	return JSON.stringify(parts).sha256_text()


func _map_locations_for(run_state: Dictionary, entry: String) -> Array:
	var found := []
	for untyped_contract in run_state.get("map_locations", []):
		var contract: Dictionary = untyped_contract
		if str(contract.get("entry", "")) == entry.to_upper():
			found.append(contract)
	return found


func _map_locations_remaining(run_state: Dictionary) -> int:
	var remaining := 0
	for untyped_contract in run_state.get("map_locations", []):
		var contract: Dictionary = untyped_contract
		remaining += (contract.get("values", []) as Array).size()
	return remaining


func _loop_boundary(run_state: Dictionary, entry: String, mark: Dictionary) -> Dictionary:
	# The current segment reached a continuation first seen at `mark`; the
	# segments between are one period of the loop. Keep the walk up to and
	# including the head, so the observation is the run that reached the loop.
	var head_index := int(mark.segment)
	var cycle := []
	for index in range(head_index, run_state.segments.size() - 1):
		var segment: Dictionary = run_state.segments[index]
		cycle.append({"entry": str(segment.entry), "offset": int(segment.offset), "status": str(segment.status)})
	var head: Dictionary = run_state.segments[head_index]
	var period_messages: int = run_state.messages.size() - int(mark.messages)
	run_state.segments.resize(head_index + 1)
	run_state.rows.resize(int(mark.rows))
	run_state.trace.resize(int(mark.trace))
	run_state.library_media.resize(int(mark.library_media))
	run_state.messages.resize(int(mark.messages))
	run_state.message_hex.resize(int(mark.message_hex))
	run_state.terminal = {
		"entry": entry,
		"status": "loop_boundary",
		"offset": int(head.offset),
		"end": int(mark.end),
		"target": "",
		"period": cycle.size(),
		"period_message_count": period_messages,
		"cycle": cycle,
	}
	return {"ok": true, "loop": true}


func _select_choice(
	provider: Dictionary,
	run_state: Dictionary,
	entry: String,
	binding: Dictionary,
	result: Dictionary
) -> Dictionary:
	var descriptor: Dictionary = run_state.descriptor
	var boundary_offset := int(result.offset)
	var choice := {}
	for untyped_choice in descriptor.get("choices", []):
		var row: Dictionary = untyped_choice
		if (
			int(row.get("boundary_offset", -1)) == boundary_offset
			and str(row.get("owner_entry", "")).to_upper() == entry.to_upper()
		):
			choice = row
	if choice.is_empty():
		# EP-12 (Core 0.368.0): carry the live stop forward instead of
		# discarding it. A caller that wants a
		# `kakyu_mes_routine40_choice_contract` for this exact boundary
		# (`measure_date_flow.gd`'s `_build_contract`, `measure_event_route.gd`'s
		# `_contract`) used to re-run the routine from a bare resume coordinate
		# to get a fresh `boundary_result`; that bare re-run lacks the
		# argument-slot/library context this walk's own `result` already
		# carries, and diverges into an unrelated `shared_routine_boundary` for
		# some sites (D's own `?_HOTEL.MES` site selector, L's own
		# `L_DATE5.MES:5945` open choice). `result` here is already the exact
		# `boundary_result` `KakyuMesRoutine40ChoiceContract.build` needs (the
		# same value the accepted-choice path just below passes it), so a
		# caller can build the contract directly from this stop instead of
		# re-running.
		return {"ok": false, "error": "no catalog choice at 0x%X in %s" % [boundary_offset, entry],
			"kind": "unanswered_choice", "entry": entry, "boundary_offset": boundary_offset,
			"result": result, "code_size": int(binding.code_size),
			"source_identity": {"entry": entry, "archive": "mes.arc"}}
	var options: Array = choice.get("options", [])
	if options.is_empty():
		return {"ok": false, "error": "catalog choice at 0x%X has no option" % boundary_offset}
	var contract_code = binding.source if binding.source != null else binding.code
	var contract := ChoiceContractScript.new().build(
		contract_code, int(binding.code_size), result, {"entry": entry, "archive": "mes.arc"}
	)
	if not contract.get("ok", false):
		return {
			"ok": false,
			"error": "routine-40 contract at 0x%X: %s" % [
				boundary_offset,
				str(contract.get("error", "")),
			],
		}
	# The first declared option, so both runs make the same choice.
	var option: Dictionary = options[0]
	var value := int(option.get("result_value", -1))
	if not value in contract.get("result_values", []):
		return {"ok": false, "error": "catalog option %d is outside the contract" % value}
	run_state.state.write_value(
		str(contract.result_storage), int(contract.result_index), value
	)
	return {
		"ok": true,
		"boundary_offset": int(contract.boundary_offset),
		"resume_offset": int(contract.resume_offset),
	}


## Runs shared routine `routine` and collects what it did. `caller` names the
## record that called it - `{caller_entry, caller_offset, caller_definition_id}`,
## built by `_walk` (the shared-call record of the walking entry) or by
## `_run_definition` (the definition's own shared-call record) - and the media
## rows of the run are anchored to the last row of `run_state.trace` (EP-14,
## `_collect_library`). A walk always has one by then; an empty `trace` is a
## refusal, before the routine runs.
func _run_library(
	provider: Dictionary,
	run_state: Dictionary,
	routine: int,
	context: Dictionary,
	caller: Dictionary
) -> Dictionary:
	if (run_state.trace as Array).is_empty():
		return {"ok": false, "error": "shared routine %d has no anchor row" % routine}
	var library_context := {
		"argument_slots": context.argument_slots.duplicate(true),
		"persistent_expression_stack": context.persistent_expression_stack.duplicate(),
		"registered_definitions": provider.definitions,
	}
	if provider.library_source != null:
		library_context["code_source"] = provider.library_source
	var library := LibraryRunnerScript.new().run(
		provider.library_code,
		provider.library_index,
		routine,
		run_state.state,
		library_context
	)
	if (
		not library.get("ok", false)
		or str(library.get("status", "")) != "library_return"
		or not library.get("messages", []).is_empty()
	):
		return {
			"ok": false,
			"error": "shared routine %d returned %s" % [
				routine,
				str(library.get("status", "no status")),
			],
		}
	_collect_library(run_state, routine, library, caller)
	return {
		"ok": true,
		"argument_slots": library.get("argument_slots", {}).duplicate(true),
		"persistent_expression_stack": library.get("persistent_expression_stack", []).duplicate(),
	}


# A registered definition invoked from a script. The definition body runs in its
# own frame and may call a shared routine, so it is driven the same way the
# route itself is: to its return, then back to the caller's resume.
func _run_definition(
	provider: Dictionary,
	run_state: Dictionary,
	terminal_row: Dictionary,
	context: Dictionary,
	depth: int = 0
) -> Dictionary:
	# Tool execution limits, not claims about the native engine's stack size.
	if depth >= 8 or int(run_state.get("definition_calls", 0)) >= 128:
		return {"ok": false, "error": "registered definition call limit exceeded"}
	run_state["definition_calls"] = int(run_state.get("definition_calls", 0)) + 1
	var definition_id := int(terminal_row.get("definition_id", -1))
	var definition: Dictionary = provider.definitions.get(definition_id, {})
	if definition.is_empty():
		return {"ok": false, "error": "definition %d is not registered" % definition_id}
	var state: KakyuMesSandboxState = run_state.state
	var arguments: Dictionary = context.argument_slots.duplicate(true)
	var stack: Array = context.persistent_expression_stack.duplicate()
	var cursor := int(definition.get("body_offset", -1))
	var poll_supplies := _poll_supplies_for(run_state, definition_id)
	for _segment in range(32):
		var continuation := definition.duplicate(false)
		continuation["body_offset"] = cursor
		var output := DefinitionCallScript.new().run(
			definition_id,
			continuation,
			state,
			{
				"argument_slots": arguments,
				"persistent_expression_stack": stack,
				"native_stream_policy": "skip_bounded",
				"native_record_policy": "omit_bounded",
				"exclude_provenance_steps": true,
				"poll_supplies": poll_supplies,
			}
		)
		for untyped_row in output.get("trace", []):
			var row: Dictionary = untyped_row
			if PROVENANCE_COMMANDS.has(int(row.get("command_id", -1))):
				continue
			run_state.rows.append(
				_signature_row("%s:%d" % [DEFINITION_ENTRY, definition_id], row)
			)
		arguments = output.get("argument_slots", {}).duplicate(true)
		stack = output.get("persistent_expression_stack", []).duplicate()
		var status := str(output.get("status", ""))
		if status == "definition_return":
			return {
				"ok": true,
				"argument_slots": arguments,
				"persistent_expression_stack": stack,
			}
		if status == "definition_invoke_boundary":
			var nested := _run_definition(provider, run_state, output.trace[-1],
				{"argument_slots": arguments, "persistent_expression_stack": stack}, depth + 1)
			if not nested.get("ok", false):
				return nested
			arguments = nested.argument_slots
			stack = nested.persistent_expression_stack
			cursor = int(output.get("resume_offset", -1))
			if cursor < 0:
				return {"ok": false, "error": "definition %d exposed no nested resume" % definition_id}
			continue
		if status != "definition_shared_routine_boundary":
			return {"ok": false, "error": "definition %d stopped at %s" % [definition_id, status],
				"entry": str(output.get("source_entry", "")), "definition_id": definition_id,
				"status": status, "offset": int(output.get("offset", -1))}
		var routine := int((output.trace[-1] as Dictionary).get("routine_id", -1))
		# EP-14: the definition's own shared-call record (DEF-relative offset)
		# is the caller of the routine's media; the route-level anchor stays
		# the `definition_invoke_boundary` row that started this definition.
		var caller := {"caller_entry": DEFINITION_ENTRY,
			"caller_offset": int((output.trace[-1] as Dictionary).get("source_offset", -1)),
			"caller_definition_id": definition_id}
		var library := _run_library(
			provider,
			run_state,
			routine,
			{"argument_slots": arguments, "persistent_expression_stack": stack},
			caller
		)
		if not library.get("ok", false):
			return library
		arguments = library.argument_slots
		stack = library.persistent_expression_stack
		cursor = int(output.get("resume_offset", -1))
		if cursor < 0:
			return {"ok": false, "error": "definition %d exposed no resume" % definition_id}
	return {"ok": false, "error": "definition %d did not return" % definition_id}


func _poll_supplies_for(run_state: Dictionary, definition_id: int) -> Array:
	var found := []
	for untyped_supply in run_state.get("poll_supplies", []):
		var supply: Dictionary = untyped_supply
		if int(supply.get("definition", -1)) == definition_id:
			found.append(supply)
	return found


func _collect(run_state: Dictionary, entry: String, result: Dictionary) -> void:
	for untyped_row in result.get("trace", []):
		var row: Dictionary = untyped_row
		# The package deliberately carries no source line markers, entry labels
		# or record separators, so the reference trace is compared without them.
		# Every other row must match exactly.
		if PROVENANCE_COMMANDS.has(int(row.get("command_id", -1))):
			continue
		run_state.rows.append(_signature_row(entry, row))
		var detailed := row.duplicate(true)
		detailed["source_entry"] = entry
		detailed["step"] = run_state.trace.size() + 1
		run_state.trace.append(detailed)
	for untyped_message in result.get("messages", []):
		var message: Dictionary = untyped_message
		run_state.message_hex.append(str(message.get("raw_hex", "")))
		var detailed := message.duplicate(true)
		detailed["source_entry"] = entry
		run_state.messages.append(detailed)


func _collect_library(run_state: Dictionary, routine: int, library: Dictionary, caller: Dictionary) -> void:
	# Core 0.378.0 (EP-14): the media rows a library run executed also travel in
	# `run_state.library_media`, a list beside `trace` and `rows`, never in
	# either. `trace` stays the route's own entries (the replay writer's
	# `resource_rows`, step numbering, the visit dispatch search and the Analysis
	# view all read it) and `rows` stays the signature's; a consumer that
	# presents media (the Playback timeline) merges this list in call order.
	# Each row is a deep copy of a library trace row whose effect is one of
	# `MEDIA_EFFECTS`, with:
	# - `source_entry`: `LIBLARY.LIB`, or `DEF_MAIN.MES` for a row carrying
	#   `external_definition_id` (the TD-55 key below); `source_offset` stays the
	#   row's own library-relative (or DEF-relative) record offset;
	# - `library_call`: `{routine, caller_entry, caller_offset,
	#   caller_definition_id}` - `routine` is the routine the caller invoked (the
	#   row keeps its own `library_routine_id`, the routine whose body holds the
	#   record, and `library_call_depth`), the rest is `caller` as `_walk` or
	#   `_run_definition` built it: the shared-call record's code-relative offset
	#   in the authoritative entry, the MES intro anchor of the medium;
	# - `trace_index`: the index in `run_state.trace` of the route row after which
	#   the library ran - the shared_routine_boundary row for a call from `_walk`,
	#   the definition_invoke_boundary row for a call from a definition body;
	# - no `step`: the library runner's own counter means nothing to a consumer.
	# `_loop_boundary` resizes the list with `rows`, so a dropped head drops its
	# media with its signature rows.
	var anchor: int = (run_state.trace as Array).size() - 1
	for untyped_row in library.get("trace", []):
		var row: Dictionary = untyped_row
		if PROVENANCE_COMMANDS.has(int(row.get("command_id", -1))):
			continue
		# Core 0.377.0 (TD-55): a registered definition invoked from inside a
		# library routine runs through the library runner, which appends the
		# definition's own rows to the library trace. They carry the definition's
		# id as `external_definition_id` and a DEF_MAIN.MES-relative offset, so
		# they are keyed by their own entry exactly like a definition the route
		# invoked itself (`_run_definition`), not as `LIBLARY.LIB:<routine>` rows
		# with a foreign offset.
		var definition_id := int(row.get("external_definition_id", -1))
		var owner := "%s:%d" % [LIBRARY_ENTRY, routine]
		if row.has("external_definition_id"):
			owner = "%s:%d" % [DEFINITION_ENTRY, definition_id]
		var signature := _signature_row(owner, row)
		signature["definition"] = definition_id
		run_state.rows.append(signature)
		if MEDIA_EFFECTS.has(str(row.get("effect", ""))):
			var media := row.duplicate(true)
			media.erase("step")
			media["source_entry"] = DEFINITION_ENTRY if row.has("external_definition_id") else LIBRARY_ENTRY
			media["library_call"] = {
				"routine": routine,
				"caller_entry": str(caller.get("caller_entry", "")),
				"caller_offset": int(caller.get("caller_offset", -1)),
				"caller_definition_id": int(caller.get("caller_definition_id", -1)),
			}
			media["trace_index"] = anchor
			run_state.library_media.append(media)


func _signature_row(entry: String, row: Dictionary) -> Dictionary:
	return {
		"entry": entry,
		"at": int(row.get("source_offset", -1)),
		"end": int(row.get("end_offset", -1)),
		"op": str(row.get("op", "")),
		"effect": str(row.get("effect", "")),
		"resource": str(row.get("resource_name", "")).to_upper(),
		"routine": int(row.get("routine_id", -1)),
		"write": "%s:%d:%d" % [
			str(row.get("write_storage", "")),
			int(row.get("write_start", -1)),
			int(row.get("write_count", -1)),
		],
	}


func context_from_documents(documents: Dictionary) -> Dictionary:
	var entries := {}
	for entry in documents:
		if entry == LIBRARY_ENTRY:
			continue
		var document: Dictionary = documents[entry]
		if not document.get("ok", false):
			return {"ok": false, "error": "A route document did not parse: %s" % str(entry)}
		entries[entry] = {
			"code": document.bytecode, "code_size": int(document.header.code_size),
			"address_table": document.header.entry_offsets.duplicate(), "source": null,
		}
	var library_document: Dictionary = documents.get(LIBRARY_ENTRY, {})
	var library_code: PackedByteArray = library_document.get("bytecode", PackedByteArray())
	var library_index := {}
	if not library_document.is_empty():
		library_index = LibraryIndexScript.new().build(library_code, library_code.size())
		if not library_index.get("ok", false):
			return {"ok": false, "error": "The route library index did not build."}
	var definitions := {}
	if documents.has(DEFINITION_ENTRY):
		var startup := StartupContextScript.new().build(documents[DEFINITION_ENTRY])
		if not startup.get("ok", false):
			return {"ok": false, "error": "The route definition registry did not build."}
		definitions = startup.get("registered_definitions", {})
	return {
		"ok": true, "entries": entries, "library_code": library_code,
		"library_source": null, "library_index": library_index, "definitions": definitions,
	}


func context_from_package(package: KakyuPlaybackPackage) -> Dictionary:
	var entries := {}
	for entry in package.entry_names():
		if entry == LIBRARY_ENTRY:
			continue
		entries[entry] = {
			"code": PackedByteArray(),
			"code_size": package.code_size(entry),
			"address_table": package.address_table(entry),
			"source": package.code_source(entry),
		}
	var definitions := {}
	if package.has_entry(DEFINITION_ENTRY):
		var startup := StartupContextScript.new().build(
			package.container_document(DEFINITION_ENTRY)
		)
		if not startup.get("ok", false):
			return {"ok": false, "error": "The packaged definition registry did not build: %s" % str(startup.get("error", ""))}
		definitions = startup.get("registered_definitions", {})
	return {
		"ok": true,
		"entries": entries,
		"library_code": PackedByteArray(),
		"library_source": package.code_source(LIBRARY_ENTRY),
		"library_index": package.library_index(LIBRARY_ENTRY),
		"definitions": definitions,
	}
