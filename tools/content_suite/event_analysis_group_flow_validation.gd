class_name KakyuEventAnalysisGroupFlowValidation
extends RefCounted

# EP-12 (2026-09-24, owner ruling): the v14 flow shape's own runtime
# validator. A sibling of the shared `event_analysis_group_validation.gd`
# rather than a branch inside it - a flow's hops have no per-route
# caller/callee pair to interleave into that script's existing branches, and
# this shape proves only synthetic archives so far. Runs each hop as its own
# `content_core/mes_route_probe.gd` call from the state the hop before it
# left, the same hand-chained technique `ep12_hotel_chain_probe.gd` and
# `ep12_date_entry_probe.gd` used to measure the real chain - not one
# continuous walk, because reaching some of a date's own branches needs
# state seeded directly at an interior offset rather than reached by natural
# execution. See docs/spec/tech/content_tools.md's v14 entry. Not yet wired
# into the shared multi-profile CLI's `GROUPS_SUMMARY` row: no real v14
# profile exists yet to run through it.
#
# EP-12 part 3 (2026-09-24): `state_context` (additive to v14, the same
# object v8 routes carry) is applied to the guard witness and every variant's
# run state before `baseline` and the variant's own writes, exactly as
# `event_analysis_group_validation.gd`'s own `_seed_route` does for v8
# (`Calendar.build` on `documents["START.MES"]`, `apply_to_state`) - the fix
# that lets a real flow through DENSHA.MES's own definition-12 branch, whose
# month scan needs the calendar table `START.MES` fills.
#
# EP-12 catalog part (2026-09-24): the hop-chain walk itself
# (`_seed_flow_state`'s ordering and the per-hop coordinate/gate/request
# mechanics) moved to the shared `KakyuEventFlowRunner`
# (`tools/content_suite/event_flow_runner.gd`), which `catalog_analysis_run.gd`
# also calls for a promoted flow row. This file keeps its own `_check`
# accounting and wording over that runner's raw per-hop data - no second copy
# of the chaining (TD-05).

const Probe := preload("res://content_core/mes_route_probe.gd")
const Runner := preload("res://content_core/mes_event_runner.gd")
const ContainerScript := preload("res://content_core/mes_container.gd")
const FlowRunner := preload("res://tools/content_suite/event_flow_runner.gd")
const Module := preload("res://tools/content_suite/event_analysis_group_validation.gd")

var failures: Array[String] = []
var checks := 0
const RUNTIME_SCHEMA := "kakyu_event_analysis_group_runtime/v14"
const PROFILE_SCHEMA := "kakyu_event_analysis_group/v14"
const REPLAY_SCHEMA := "kakyu_event_analysis_group_replay/v3"

# EP-12 / WD unit 2 (2026-09-25): `--replay` for a v14 flow profile, wired
# through the same shared CLI (`validate_event_analysis_group.gd`) and the
# same pure per-message/per-terminal helpers (`shared._message_rows`,
# `shared._replay_terminal`) the v6/v13 replay path already uses - one code
# path, not a second copy. The written envelope matches v8's own
# (`schema kakyu_event_analysis_group_replay/v2`, `group_id`,
# `payload_sha256`, `archive_sha256`, `profile`, `routes[]`); only
# `runtime_schema` (`kakyu_event_analysis_group_runtime/v14`) and each
# route's own shape (`route_id`, `origin`, `terminal`, `variants[]`, each
# variant `{variant_id, writes, reached, hops[...], messages, final_state,
# state_changes, terminal}`) are v14's own. Every value here is read
# straight from `KakyuEventFlowRunner.run_route`'s own per-hop/per-run data,
# never re-run or re-derived.
#
# WD-21 U2 C2 (2026-10-08): the written file is now
# `kakyu_event_analysis_group_replay/v3`: each hop additionally carries
# `executed` and `resource_rows` (what that hop's probe result executed, and
# which media effects its own entries requested), computed by the shared
# `replay_run_media.gd` through `shared._replay_run_media` - the same
# attribution rule the site writer uses, in one place. Every other field is
# the v2 one. See analysis/_docs/wd21_u2_spec.md D2.
var do_replay := false
var replay_path := ""
var replay_routes: Array = []
var shared: KakyuEventAnalysisGroupValidation


func validate(elfimage_path: String, profile_path: String, replay_path_arg := "", shared_module: KakyuEventAnalysisGroupValidation = null) -> Dictionary:
	var start_ticks := Time.get_ticks_usec()
	do_replay = replay_path_arg != ""
	replay_path = replay_path_arg
	shared = shared_module if shared_module != null else Module.new()
	var output: Array = []
	var exit_code := OS.execute("py", ["tools/audit_event_analysis_group.py", elfimage_path, "--profile", profile_path], output, true)
	var parsed: Variant = JSON.parse_string("".join(output))
	var audited: Dictionary = parsed if parsed is Dictionary else {}
	_check(exit_code == 0 and audited.get("ok", false), "Python exact flow source audit")
	if not failures.is_empty():
		return _finish(start_ticks)
	var profile: Dictionary = audited.profile
	_check(profile.get("schema", "") == PROFILE_SCHEMA, "profile declares the v14 flow schema")
	if not failures.is_empty():
		return _finish(start_ticks)

	var reader := preload("res://content_core/arc_reader.gd").new()
	var owns_reader := true
	_check(reader.open(elfimage_path.path_join("mes.arc")) and reader.get_archive_fingerprint() == profile.archive_sha256,
		"original archive identity")
	if not failures.is_empty():
		if owns_reader: reader.close()
		return _finish(start_ticks)
	var documents := {}
	for untyped_member in profile.source_members:
		var member: Dictionary = untyped_member
		_check(reader.get_entry_fingerprint(member.entry) == member.entry_sha256, "original member %s" % member.entry)
		documents[member.entry] = ContainerScript.new().parse(reader.read_entry(member.entry), {"entry":member.entry,"archive":"mes.arc"})
	var probe := Probe.new()
	var provider := probe.context_from_documents(documents)
	_check(provider.get("ok", false), "library and definition context")
	if not failures.is_empty():
		if owns_reader: reader.close()
		return _finish(start_ticks)

	for untyped_route in profile.routes:
		_run_route(probe, provider, documents, untyped_route, reader)
	if do_replay:
		var out := {
			"schema": REPLAY_SCHEMA,
			"profile": profile_path.get_file().get_basename(),
			"group_id": profile.group_id,
			"payload_sha256": profile.payload_sha256,
			"archive_sha256": profile.archive_sha256,
			"runtime_schema": RUNTIME_SCHEMA,
			"routes": replay_routes,
		}
		var replay_dir := replay_path.get_base_dir()
		if replay_dir != "":
			DirAccess.make_dir_recursive_absolute(replay_dir)
		var replay_file := FileAccess.open(replay_path, FileAccess.WRITE)
		replay_file.store_string(JSON.stringify(out, "\t"))
		replay_file.close()
		var variant_total := 0
		for replay_route in replay_routes:
			variant_total += (replay_route as Dictionary).get("variants", []).size()
		print("REPLAY_WRITTEN %s routes=%d variants=%d %s" % [replay_path, replay_routes.size(), variant_total, shared.replay_media_summary()])
	if owns_reader: reader.close()
	return _finish(start_ticks)


# `route.state_context` applied before `route.baseline` and `writes`, exactly
# as `event_analysis_group_validation.gd`'s own `_seed_route` does for a v8
# continuation route (see this file's own EP-12 part 3 header comment). Now
# `KakyuEventFlowRunner.seed_flow_state`'s own logic (TD-05: the guard-witness
# seeding here and the runner's own per-variant seeding share it); this
# wrapper only keeps this file's `_check` accounting over its `checks` list.
func _seed_flow_state(route: Dictionary, writes: Array, documents: Dictionary) -> KakyuMesSandboxState:
	var seeded := FlowRunner.seed_flow_state(route, writes, documents)
	for untyped_check in seeded.checks:
		var check: Dictionary = untyped_check
		_check(bool(check.ok), str(check.label))
	return seeded.state


func _run_route(probe: KakyuMesRouteProbe, provider: Dictionary, documents: Dictionary, route: Dictionary, reader: KakyuArcReader) -> void:
	var origin: Dictionary = route.origin
	var guard: Dictionary = origin.guard
	var origin_entry: String = origin.entry
	for untyped_witness in origin.guard_cases:
		var witness: Dictionary = untyped_witness
		var witness_state := _seed_flow_state(route, witness.writes, documents)
		var code: PackedByteArray = provider.entries[origin_entry].code
		var result := Runner.new().run(code, int(guard.offset), witness_state, int(provider.entries[origin_entry].code_size), 1)
		var trace: Array = result.get("trace", [])
		var row: Dictionary = trace[0] if trace.size() == 1 else {}
		_check(int(row.get("source_offset", -1)) == int(guard.offset) and int(row.get("end_offset", -1)) == int(guard.end)
			and int(row.get("condition_value", -1)) == int(witness.expected)
			and int(row.get("next_offset", -1)) == (int(guard.end) if int(witness.expected) == 1 else int(guard.false_target)),
			"%s guard %s" % [route.route_id, witness.case_id])

	# EP-12 catalog part: the hop-chain walk itself is
	# `KakyuEventFlowRunner.run_route` (TD-05, shared with
	# `catalog_analysis_run.gd`); this loop keeps only the assertions this
	# file always made, now read from the runner's own per-hop `hops[]` data
	# instead of interleaving them into the walk.
	var replay_variants: Array = []
	for untyped_variant in route.variants:
		var variant: Dictionary = untyped_variant
		var result := FlowRunner.run_route(probe, provider, documents, route, variant, {})
		for untyped_check in result.seed_checks:
			var check: Dictionary = untyped_check
			_check(bool(check.ok), str(check.label))
		for failure in result.failures:
			_check(false, str(failure))
		var hops: Array = route.hops
		var replay_hops: Array = []
		for index in range(hops.size()):
			var hop: Dictionary = hops[index]
			var hop_report: Dictionary = result.hops[index]
			var run: Dictionary = hop_report.run
			for untyped_gate_read in hop_report.gate_reads:
				var gate_read: Dictionary = untyped_gate_read
				var gate: Dictionary = gate_read.gate
				_check(_gate_holds(int(gate_read.actual), str(gate.op), int(gate.value)),
					"%s %s hop %s gate holds on entry" % [route.route_id, variant.variant_id, hop.hop_id])
			var expected: Dictionary = hop.expected
			var outcome: Dictionary = expected.outcome
			_check(_hop_reached(run, str(hop_report.entry), outcome),
				"%s %s hop %s reaches its declared outcome" % [route.route_id, variant.variant_id, hop.hop_id])
			_check(int((run.messages as Array).size()) == FlowRunner.hop_message_count(hop, variant),
				"%s %s hop %s message count" % [route.route_id, variant.variant_id, hop.hop_id])
			var run_state: KakyuMesSandboxState = run.state_object
			for untyped_write in expected.expected_state:
				var write: Dictionary = untyped_write
				_check(run_state.read_value(str(write.storage), int(write.index), int(write.bank)) == int(write.value),
					"%s %s hop %s writes" % [route.route_id, variant.variant_id, hop.hop_id])
			if do_replay:
				var hop_media: Dictionary = shared._replay_run_media(run, "%s %s hop %s" % [route.route_id, variant.variant_id, hop.hop_id], failures)
				replay_hops.append({
					"hop_id": str(hop_report.hop_id),
					"entry": str(hop_report.entry),
					"start_coordinate": int(hop_report.start_coordinate),
					"messages": shared._message_rows(run, reader),
					"executed": hop_media.executed,
					"resource_rows": hop_media.resource_rows,
					"message_count": (run.get("messages", []) as Array).size(),
					"state_changes": run.get("state_diff", []),
					"terminal": shared._replay_terminal(run),
				})
		var last_outcome: Dictionary = (hops[-1] as Dictionary).expected.outcome
		var terminal: Dictionary = route.terminal
		_check(str(terminal.entry) == str((hops[-1] as Dictionary).entry) and int(terminal.offset) == int(last_outcome.offset)
			and int(terminal.end) == int(last_outcome.end) and str(terminal.status) == str(last_outcome.status),
			"%s %s terminal is reached" % [route.route_id, variant.variant_id])
		if do_replay:
			var seed_ok := true
			for untyped_check in result.seed_checks:
				var check: Dictionary = untyped_check
				if not bool(check.ok): seed_ok = false
			replay_variants.append({
				"variant_id": str(variant.variant_id),
				"writes": variant.get("writes", []),
				"reached": bool(result.ok) and seed_ok,
				"hops": replay_hops,
				"messages": shared._message_rows(result, reader),
				"final_state": result.get("state", []),
				"state_changes": result.get("state_diff", []),
				"terminal": shared._replay_terminal(result),
			})
	if do_replay:
		replay_routes.append({
			"route_id": str(route.route_id),
			"origin": route.get("origin", {}),
			"terminal": route.get("terminal", {}),
			"variants": replay_variants,
		})


func _hop_reached(result: Dictionary, entry: String, outcome: Dictionary) -> bool:
	# `run_route`'s own top-level "ok" stays true for a requested analysis stop
	# (missing-package-member is the only case it reports false for); "stop"/
	# "stop_detail" carry whether the walk reached a natural terminal or an
	# analysis-requested one instead, the same reading
	# `event_analysis_group_validation.gd`'s own checks use.
	var status := str(outcome.status)
	if status == "script_dispatch_boundary":
		var detail: Dictionary = result.get("stop_detail", {})
		return result.get("ok", false) and str(detail.get("status", "")) == "analysis_dispatch_stop" \
			and str(detail.get("entry", "")) == entry and int(detail.get("offset", -1)) == int(outcome.offset) \
			and int(detail.get("end", -1)) == int(outcome.end) \
			and str(detail.get("target", "")).to_upper() == str(outcome.get("target", "")).to_upper()
	if status == "def_selection_boundary":
		var expected_stop := "no catalog choice at 0x%X in %s" % [int(outcome.offset), entry]
		return result.get("ok", false) and str(result.get("stop", "")) == expected_stop
	var terminal: Dictionary = result.get("terminal", {})
	var ok: bool = result.get("ok", false) and str(terminal.get("entry", "")) == entry and str(terminal.get("status", "")) == status \
		and int(terminal.get("offset", -1)) == int(outcome.offset) and int(terminal.get("end", -1)) == int(outcome.end)
	if status == "script_handoff_boundary":
		ok = ok and str(terminal.get("target", "")).to_upper() == str(outcome.get("target", "")).to_upper()
	return ok


func _gate_holds(actual: int, op: String, value: int) -> bool:
	match op:
		"equal": return actual == value
		"not_equal": return actual != value
		"greater_than": return actual > value
		"less_than": return actual < value
		"greater_or_equal": return actual >= value
		"less_or_equal": return actual <= value
		_: return false


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)


func _finish(start_ticks: int) -> Dictionary:
	return {
		"ok": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"runtime_schema": RUNTIME_SCHEMA,
		"duration_seconds": (Time.get_ticks_usec() - start_ticks) / 1000000.0,
	}
