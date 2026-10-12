extends SceneTree

# Replays a catalog event's presets in the bounded route probe (the same
# instrument validate_catalog_analysis_routes.gd uses) and records the
# message trace of every preset, plus the completed reentry, as offsets only.
#
# Usage: replay_event_dialogue.gd <ELFIMAGE-directory> <catalog json> <event_id> <out json>
#
# Never prints or writes original dialogue text: only entry/offset/end and a
# SHA-256 of the message's raw CP932 bytes leave this script.

const Catalog := preload("res://content_core/event_catalog.gd")
const Probe := preload("res://content_core/mes_route_probe.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const ArcReaderScript := preload("res://content_core/arc_reader.gd")
const CalendarScript := preload("res://content_core/mes_calendar_state.gd")
const StateScript := preload("res://content_core/mes_sandbox_state.gd")
const START_ENTRY := "START.MES"


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 4:
		push_error("Usage: replay_event_dialogue.gd <ELFIMAGE-directory> <catalog json> <event_id> <out json>")
		quit(2)
		return
	var elfimage_dir := str(arguments[0]).replace("\\", "/")
	while elfimage_dir.ends_with("/"):
		elfimage_dir = elfimage_dir.substr(0, elfimage_dir.length() - 1)
	var catalog_path := str(arguments[1])
	var event_id := str(arguments[2])
	var out_path := str(arguments[3])

	var catalog := Catalog.new()
	var loaded := catalog.load_file(catalog_path)
	if not loaded.get("ok", false):
		push_error("Catalog did not load: %s" % catalog.last_error)
		quit(1)
		return
	var event: Dictionary = catalog.get_event(event_id)
	if event.is_empty():
		push_error("Event not found in catalog: %s" % event_id)
		quit(1)
		return

	var reader := ArcReaderScript.new()
	if not reader.open(elfimage_dir.path_join("mes.arc")):
		push_error("Archive did not open: %s" % reader.last_error)
		quit(1)
		return
	var archive_sha256 := reader.get_archive_fingerprint()

	var members: Array[Dictionary] = Catalog.source_members_for_events([event])
	members.append(event.source.caller as Dictionary)
	var documents := {}
	for untyped_member in members:
		var member: Dictionary = untyped_member
		documents[member.entry] = ContainerScript.new().parse(reader.read_entry(str(member.entry)))
	# The startup definition registry: a shared routine may invoke a
	# definition DEF_MAIN.MES registers at startup (routine 25 invokes
	# definition 26), and the probe can only run it when the registry is
	# among its documents. Loaded whenever the archive carries it.
	if not documents.has(Probe.DEFINITION_ENTRY) and not reader.get_entry(Probe.DEFINITION_ENTRY).is_empty():
		documents[Probe.DEFINITION_ENTRY] = ContainerScript.new().parse(reader.read_entry(Probe.DEFINITION_ENTRY))
	# The audited calendar projection: definition 12 scans the calendar table
	# START.MES builds at startup, so a run whose route reaches it needs the
	# table in its sandbox (the Event Player seeds the same projection). Only
	# the audited table is seeded; a changed START.MES seeds nothing.
	var calendar_projection := {}
	if not reader.get_entry(START_ENTRY).is_empty():
		var start_document: Dictionary = ContainerScript.new().parse(reader.read_entry(START_ENTRY))
		var built: Dictionary = CalendarScript.new().build(start_document)
		if built.get("ok", false) and str(built.get("table_sha256", "")) == CalendarScript.AUDITED_TABLE_SHA256:
			calendar_projection = built
	for entry_name in documents.keys():
		var document: Dictionary = documents[entry_name]
		if not document.get("ok", false):
			push_error("Member document did not parse: %s" % str(entry_name))
			quit(1)
			return

	var probe := Probe.new()
	var provider := probe.context_from_documents(documents)
	if not provider.get("ok", false):
		push_error("Route provider did not build: %s" % str(provider.get("error", "")))
		quit(1)
		return
	# Entries the routes needed beyond the catalog row's declared members
	# (a nested presentation script the row does not list). They are loaded
	# from the archive on demand, at most a few per run, and reported in the
	# output so the row can be completed.
	var extra_members: Array = []

	# Allowed final-state cells: the terminals' required_state rows and the
	# presets' own writes. Anything else is dropped from the recorded final
	# state so the replay output stays bounded to what the catalog declares.
	var allowed_cells := {}
	for untyped_terminal in event.get("terminals", []):
		var terminal: Dictionary = untyped_terminal
		for untyped_row in terminal.get("required_state", []):
			var row: Dictionary = untyped_row
			allowed_cells[_cell_key(row)] = true
	for untyped_preset in event.get("presets", []):
		var preset: Dictionary = untyped_preset
		for untyped_row in preset.get("writes", []):
			var row: Dictionary = untyped_row
			allowed_cells[_cell_key(row)] = true

	var caller_entry := str(event.source.caller.entry)
	# Most catalog rows record no analysis_route (only EVENTJ04 does today):
	# the caller prefix cannot be replayed without its start coordinate, so
	# it is skipped entirely for those rows - the callee run below does not
	# need it, since it starts directly from callee.start_coordinate.
	var has_analysis_route := event.has("analysis_route")
	var caller_start := -1
	var expected_caller_terminal := {}
	if has_analysis_route:
		caller_start = int(event.analysis_route.caller_start_coordinate)
		expected_caller_terminal = {
			"entry": caller_entry,
			"status": "script_handoff_boundary",
			"offset": int(event.source.caller.dispatch_offset),
			"end": int(event.source.caller.resume_offset),
			"target": str(event.source.callee.entry),
		}
	var callee_entry := str(event.source.callee.entry)
	var callee_start := int(event.source.callee.start_coordinate)
	var choices: Array = event.get("choices", [])

	var runs: Array = []
	var ok := true

	# A catalog row with no presets (EVENTD05, EVENTD06) still has one route
	# to replay: the callee from its own start_coordinate, no seed writes.
	var event_presets: Array = event.get("presets", [])
	if event_presets.is_empty():
		event_presets = [{"preset_id": "baseline", "writes": []}]

	for untyped_preset in event_presets:
		var preset: Dictionary = untyped_preset
		var preset_id := str(preset.get("preset_id", ""))
		var prefix_state_changes: Array = []
		if has_analysis_route:
			var prefix := probe.run_route(provider, {"entry": caller_entry, "start_coordinate": caller_start}, preset)
			if not (prefix.get("ok", false) and str(prefix.get("stop", "failure")).is_empty() and prefix.terminal == expected_caller_terminal):
				push_error("Caller prefix did not reach the declared handoff for preset %s" % preset_id)
				ok = false
				continue
			prefix_state_changes = prefix.get("state_diff", [])

		var options: Array = []
		var has_choice := false
		for untyped_choice in choices:
			var choice_row: Dictionary = untyped_choice
			var choice_options: Array = choice_row.get("options", [])
			if not choice_options.is_empty():
				has_choice = true
				for untyped_option in choice_options:
					options.append(untyped_option)
		if not has_choice:
			options = [{}]

		for untyped_option in options:
			var option: Dictionary = untyped_option
			var route := {"entry": callee_entry, "start_coordinate": callee_start, "choices": choices}
			if has_choice:
				# Reorder each choice's options so the wanted option is first;
				# _select_choice always takes the first declared option.
				var reordered_choices: Array = []
				for untyped_choice in choices:
					var choice_row: Dictionary = (untyped_choice as Dictionary).duplicate(true)
					var choice_options: Array = choice_row.get("options", [])
					if int(option.get("result_value", -2)) in _option_values(choice_options):
						var ordered: Array = [option]
						for untyped_other in choice_options:
							if untyped_other != option:
								ordered.append(untyped_other)
						choice_row["options"] = ordered
					reordered_choices.append(choice_row)
				route["choices"] = reordered_choices

			var direct := probe.run_route(provider, route, preset, _seed_state(calendar_projection))
			for _attempt in range(8):
				var missing := _missing_member(direct)
				if missing.is_empty() or documents.has(missing) or reader.get_entry(missing).is_empty():
					break
				documents[missing] = ContainerScript.new().parse(reader.read_entry(missing))
				if not documents[missing].get("ok", false):
					break
				provider = probe.context_from_documents(documents)
				if not provider.get("ok", false):
					break
				if not extra_members.has(missing):
					extra_members.append(missing)
				direct = probe.run_route(provider, route, preset, _seed_state(calendar_projection))
			var stop := str(direct.get("stop", ""))
			if not direct.get("ok", false) or not stop.is_empty():
				var boundary := _matching_analysis_boundary(event, direct, callee_entry)
				if boundary.is_empty():
					push_error("Callee run failed for preset %s: %s (last %s row at %d)" % [
						preset_id, str(direct.get("stop", direct.get("error", ""))), callee_entry, _stop_offset(direct, callee_entry)])
					ok = false
					continue
				# A declared analysis_boundary is a known, catalogued stop (a
				# shared routine or registered definition the bounded probe
				# cannot execute past): record it as this run's terminal
				# instead of failing the whole replay.
				direct = direct.duplicate(true)
				direct["terminal"] = {
					"entry": callee_entry,
					"status": str(direct.get("stop_detail", {}).get("status", stop)),
					"offset": int(boundary.offset),
					"end": int(boundary.get("caller_resume_offset", boundary.offset)),
					"target": "",
				}

			var message_rows := _message_rows(direct, reader)
			var final_state := _filtered_state(direct.state_object, allowed_cells)

			var reentry := probe.run_route(provider, route, {"writes": direct.state}, _seed_state(calendar_projection))
			var reentry_terminal: Dictionary = reentry.get("terminal", {})
			var reentry_message_count: int = (reentry.get("messages", []) as Array).size()

			var run := {
				"preset_id": preset_id,
				"option": option.get("result_value", null) if has_choice else null,
				"terminal": direct.terminal,
				"messages": message_rows,
				"final_state": final_state,
				"reentry": {
					"terminal": reentry_terminal,
					"message_count": reentry_message_count,
				},
				"state_changes": {
					"prefix": prefix_state_changes,
					"callee": direct.get("state_diff", []),
					"reentry": reentry.get("state_diff", []),
				},
			}
			runs.append(run)
			var label := preset_id
			if has_choice:
				label = "%s/%s" % [preset_id, str(option.get("result_value", ""))]
			print("REPLAY %s messages=%d terminal=%s" % [label, message_rows.size(), str(direct.terminal.get("offset", -1))])

	var out := {
		"schema": "kakyu_event_dialogue_replay/v2",
		"event_id": event_id,
		"archive_sha256": archive_sha256,
		"caller_prefix_replayed": has_analysis_route,
		"extra_members": extra_members,
		"runs": runs,
	}
	if not ok:
		quit(1)
		return

	var directory := out_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open output for writing: %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(out, "\t"))
	file.close()

	print("REPLAY_OK")
	quit(0)


func _option_values(options: Array) -> Array:
	var values := []
	for untyped_option in options:
		values.append(int((untyped_option as Dictionary).get("result_value", -1)))
	return values


# The offset a declared analysis boundary is matched against: the last
# trace row the route's own entry emitted. A stop inside a shared routine or
# a registered definition reports its own offset in `stop_detail`, but the
# catalog declares the boundary at the event's call site, which is that last
# entry row (the call). Only a route with no entry row at all falls back to
# `stop_detail.offset`.
func _stop_offset(direct: Dictionary, entry: String) -> int:
	var trace: Array = direct.get("trace", [])
	for index in range(trace.size() - 1, -1, -1):
		var row: Dictionary = trace[index]
		if str(row.get("source_entry", "")) == entry:
			return int(row.get("source_offset", -1))
	var detail: Dictionary = direct.get("stop_detail", {})
	if detail.has("offset"):
		return int(detail.offset)
	return -1


# The entry name a "nested entry X is not a package member" stop names, or
# "" for any other outcome.
func _missing_member(direct: Dictionary) -> String:
	var stop := str(direct.get("stop", ""))
	if not stop.begins_with("nested entry ") or not stop.ends_with(" is not a package member"):
		return ""
	return stop.trim_prefix("nested entry ").trim_suffix(" is not a package member")


# A fresh sandbox with the audited calendar table seeded when the archive
# supplied one; the probe overlays the preset on a private clone of it.
func _seed_state(calendar_projection: Dictionary) -> KakyuMesSandboxState:
	var state: KakyuMesSandboxState = StateScript.new(1)
	if not calendar_projection.is_empty():
		CalendarScript.new().apply_to_state(calendar_projection, state)
	return state


func _matching_analysis_boundary(event: Dictionary, direct: Dictionary, entry: String) -> Dictionary:
	var offset := _stop_offset(direct, entry)
	if offset < 0:
		return {}
	for untyped_terminal in event.get("terminals", []):
		var terminal: Dictionary = untyped_terminal
		if str(terminal.get("kind", "")) == "analysis_boundary" and int(terminal.get("offset", -1)) == offset:
			return terminal
	return {}


func _cell_key(row: Dictionary) -> String:
	return "%s:%d:%d" % [str(row.get("storage", "")), int(row.get("bank", 0)), int(row.get("index", -1))]


func _filtered_state(state: KakyuMesSandboxState, allowed_cells: Dictionary) -> Array:
	var rows := []
	for record in state.to_records():
		var row: Dictionary = record
		if allowed_cells.has(_cell_key(row)):
			rows.append(row)
	rows.sort_custom(func(a, b): return _cell_key(a) < _cell_key(b))
	return rows


func _message_rows(direct: Dictionary, reader: KakyuArcReader) -> Array:
	var trace_by_key := {}
	for untyped_row in direct.get("trace", []):
		var row: Dictionary = untyped_row
		var key := "%s:%d" % [str(row.get("source_entry", "")), int(row.get("source_offset", -1))]
		if not trace_by_key.has(key):
			trace_by_key[key] = row

	var rows := []
	for untyped_message in direct.get("messages", []):
		var message: Dictionary = untyped_message
		var entry := str(message.get("source_entry", ""))
		var offset := int(message.get("source_offset", -1))
		var key := "%s:%d" % [entry, offset]
		var trace_row: Dictionary = trace_by_key.get(key, {})
		var end_offset := int(trace_row.get("end_offset", -1))
		var raw_bytes: PackedByteArray = message.get("raw_bytes", PackedByteArray())
		var raw_sha256 := _sha256_bytes(raw_bytes)
		rows.append({
			"entry": entry,
			"offset": offset,
			"end": end_offset,
			"raw_sha256": raw_sha256,
		})
	return rows


func _sha256_bytes(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
